// Drive Twingate's menu bar menu through the Accessibility API. Login has to
// start in the app (it begins the Okta flow and receives the redirect), so
// opening the auth page directly is not enough. A standalone binary so
// Accessibility can be granted to it alone instead of to osascript.
//
// usage: twingate_menu login    press "Log in to ..."
//        twingate_menu logout   press "Log Out & Disconnect"
import AppKit
import ApplicationServices

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    FileHandle.standardError.write("twingate_menu: \(message)\n".data(using: .utf8)!)
    exit(code)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

let args = CommandLine.arguments
let prefixes = ["login": "Log in", "logout": "Log Out"]
guard args.count == 2, let prefix = prefixes[args[1]] else {
    fail("usage: twingate_menu <login|logout>", 2)
}

guard AXIsProcessTrusted() else { fail("not trusted for Accessibility") }

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.twingate.macos").first else {
    fail("Twingate is not running")
}

let axApp = AXUIElementCreateApplication(app.processIdentifier)
guard let extras = attribute(axApp, "AXExtrasMenuBar"),
      let statusItem = children(extras as! AXUIElement).first
else { fail("Twingate menu bar item not found") }

// pressing a status item can report cannotComplete while its menu is
// tracking, even though the menu opened
AXUIElementSetMessagingTimeout(axApp, 1.0)
let pressed = AXUIElementPerformAction(statusItem, kAXPressAction as CFString)
guard pressed == .success || pressed == .cannotComplete else {
    fail("could not open the Twingate menu (\(pressed.rawValue))")
}

// the menu is populated once open
var target: AXUIElement?
for _ in 0..<20 {
    for menu in children(statusItem) {
        target = children(menu).first {
            (attribute($0, kAXTitleAttribute) as? String)?.hasPrefix(prefix) == true
        }
        if target != nil { break }
    }
    if target != nil { break }
    usleep(50_000)
}

guard let target else {
    for menu in children(statusItem) {
        AXUIElementPerformAction(menu, kAXCancelAction as CFString)
    }
    fail("no menu item starting with \"\(prefix)\"")
}

guard AXUIElementPerformAction(target, kAXPressAction as CFString) == .success else {
    fail("could not press \"\(prefix)\"")
}
