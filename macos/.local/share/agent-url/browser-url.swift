import AppKit
import ApplicationServices
import Foundation

struct CaptureError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func validURL(_ text: String) -> String? {
    guard !text.isEmpty, text.utf8.count <= 65536,
          !text.unicodeScalars.contains(where: { $0.value <= 32 || $0.value == 127 }),
          let components = URLComponents(string: text),
          let scheme = components.scheme, !scheme.isEmpty else { return nil }
    if ["http", "https", "ftp"].contains(scheme.lowercased()),
       components.host?.isEmpty != false { return nil }
    return text
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
        return nil
    }
    return value
}

func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = attribute(element, name),
          CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

func sendKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }
}

func captureURL() throws -> String {
    guard let browser = NSWorkspace.shared.frontmostApplication,
          let bundle = browser.bundleIdentifier else {
        throw CaptureError(message: "Cannot identify the frontmost application.")
    }
    // Never take a stale URL from some other browser running in the background.
    let browsers = [
        "org.mozilla.firefox", "org.mozilla.nightly", "org.mozilla.firefoxdeveloperedition",
        "app.zen-browser.zen", "company.thebrowser.Browser", "com.apple.Safari",
        "com.apple.SafariTechnologyPreview", "com.brave.Browser", "com.google.Chrome",
        "com.microsoft.edgemac", "com.vivaldi.Vivaldi", "com.operasoftware.Opera"
    ]
    guard browsers.contains(where: { bundle == $0 || bundle.hasPrefix($0 + ".") }) else {
        throw CaptureError(message: "Focus a browser tab first (frontmost: \(browser.localizedName ?? bundle)).")
    }
    guard AXIsProcessTrusted() else {
        throw CaptureError(message: "URL capture needs Accessibility access. When invoked by a hotkey, enable Tinycast in System Settings → Privacy & Security → Accessibility. For direct terminal use, enable your terminal there.")
    }
    let modifiers: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
    let deadline = Date().addingTimeInterval(3)
    while !CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty {
        guard Date() < deadline else {
            throw CaptureError(message: "Release Hyper and Shift, then try the shortcut again.")
        }
        Thread.sleep(forTimeInterval: 0.02)
    }
    func checkFocus() throws {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.processIdentifier else {
            throw CaptureError(message: "Browser focus changed during URL capture. Please try again.")
        }
    }
    try checkFocus()
    let app = AXUIElementCreateApplication(browser.processIdentifier)
    AXUIElementSetMessagingTimeout(app, 1)
    // Firefox and Safari commonly expose the full URL on the focused window.
    if let window = elementAttribute(app, kAXFocusedWindowAttribute),
       let document = attribute(window, kAXDocumentAttribute) as? String,
       let url = validURL(document) {
        return url
    }
    // Chromium and browsers without AXDocument: focus the address bar, then read
    // its AXValue. Clipboard contents (including rich text/images) are untouched.
    sendKey(37, flags: .maskCommand) // Cmd+L
    defer {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == browser.processIdentifier {
            sendKey(53) // Escape, returning from the address bar without navigation
        }
    }
    let focusDeadline = Date().addingTimeInterval(1.5)
    while Date() < focusDeadline {
        Thread.sleep(forTimeInterval: 0.04)
        try checkFocus()
        if let field = elementAttribute(app, kAXFocusedUIElementAttribute),
           let value = attribute(field, kAXValueAttribute) as? String,
           let url = validURL(value) {
            return url
        }
    }
    throw CaptureError(message: "The browser did not expose its address-bar URL. Check Accessibility access for Tinycast.")
}

do {
    if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--validate-url" {
        guard let url = validURL(CommandLine.arguments[2]) else {
            throw CaptureError(message: "Invalid URL")
        }
        print(url)
    } else {
        print(try captureURL())
    }
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
