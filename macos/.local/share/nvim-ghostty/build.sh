#!/bin/bash
# Build NvimGhostty.app: an .app bundle that opens documents in Neovim inside
# Ghostty, so macOS Launch Services has something it can assign as a handler.
#
# Usage: ./build.sh [--register]
#
#   --register  also make the app the default handler for JSON via duti

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${NVIM_GHOSTTY_APP_DIR:-$HOME/Applications}"
APP="$APP_DIR/NvimGhostty.app"
BUNDLE_ID="com.peterbenjamin.nvim-ghostty"
PLIST_BUDDY=/usr/libexec/PlistBuddy
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# UTIs to claim. public.json covers .json; the JSON-adjacent formats below have
# no system UTI, so they are claimed by extension instead.
UTIS=(public.json)
EXTENSIONS=(json jsonc json5 ndjson jsonl)

register=false
[[ "${1:-}" == "--register" ]] && register=true

log() { printf '==> %s\n' "$*"; }

# osacompile emits a minimal Info.plist, so most keys need Add rather than Set.
plist_set() { # <plist> <key> <type> <value>
	$PLIST_BUDDY -c "Set :$2 $4" "$1" 2>/dev/null ||
		$PLIST_BUDDY -c "Add :$2 $3 $4" "$1"
}

log "compiling $APP"
mkdir -p "$APP_DIR"
rm -rf "$APP"
osacompile -o "$APP" "$SRC_DIR/nvim-ghostty.applescript"

log "installing shell wrapper"
install -m 0755 "$SRC_DIR/open-in-nvim" "$APP/Contents/Resources/open-in-nvim"

log "patching Info.plist"
plist="$APP/Contents/Info.plist"
plist_set "$plist" CFBundleIdentifier string "$BUNDLE_ID"
plist_set "$plist" CFBundleName string NvimGhostty
plist_set "$plist" CFBundleDisplayName string NvimGhostty
plist_set "$plist" NSHighResolutionCapable bool true

# Declaring a document type is what makes the app selectable as a handler at
# all; without it Finder's "Open With" list will never show it.
$PLIST_BUDDY -c "Delete :CFBundleDocumentTypes" "$plist" 2>/dev/null || true
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes array" "$plist"
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0 dict" "$plist"
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 'JSON Document'" "$plist"
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$plist"
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$plist"
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$plist"
for i in "${!UTIS[@]}"; do
	$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string ${UTIS[$i]}" "$plist"
done
$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$plist"
for i in "${!EXTENSIONS[@]}"; do
	$PLIST_BUDDY -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:$i string ${EXTENSIONS[$i]}" "$plist"
done

# Editing Info.plist invalidates osacompile's ad-hoc signature.
log "re-signing bundle"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

log "refreshing Launch Services"
touch "$APP"
"$LSREGISTER" -f "$APP"

if [[ "$register" == true ]]; then
	if ! command -v duti >/dev/null 2>&1; then
		echo "duti not found; install it with 'brew install duti' and re-run with --register" >&2
		exit 1
	fi
	log "registering $BUNDLE_ID as the default JSON handler"
	for uti in "${UTIS[@]}"; do
		duti -s "$BUNDLE_ID" "$uti" all
	done
	for ext in "${EXTENSIONS[@]}"; do
		duti -s "$BUNDLE_ID" ".$ext" all
	done
fi

log "done: $APP"
