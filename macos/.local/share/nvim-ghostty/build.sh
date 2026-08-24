#!/bin/bash
# Build NvimGhostty.app: an .app bundle that opens documents in Neovim inside
# Ghostty, so macOS Launch Services has something it can assign as a handler.
#
# The claimed document types live in filetypes.conf, one group per line-block.
#
# Usage: ./build.sh [--register [group...]]
#
#   --register  after building, make the app the default handler for the named
#               groups via duti (default: data). Declaring types is harmless;
#               registering them takes files away from their current app, so it
#               is opt-in per group.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SRC_DIR/filetypes.conf"
APP_DIR="${NVIM_GHOSTTY_APP_DIR:-$HOME/Applications}"
APP="$APP_DIR/NvimGhostty.app"
BUNDLE_ID="com.peterbenjamin.nvim-ghostty"
PLIST_BUDDY=/usr/libexec/PlistBuddy
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

log() { printf '==> %s\n' "$*"; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

# --- filetypes.conf ---------------------------------------------------------
# Kept to awk and flat strings rather than associative arrays: /bin/bash on
# macOS is 3.2, which has neither those nor namerefs.

conf_groups() {
	awk -F: '/^[[:space:]]*#/ || NF < 3 { next } { gsub(/[[:space:]]/, "", $1); print $1 }' \
		"$CONF" | awk '!seen[$0]++'
}

# conf_get <group> <role> -> the row's values, space separated
conf_get() {
	awk -F: -v g="$1" -v r="$2" '
		/^[[:space:]]*#/ || NF < 3 { next }
		{
			gsub(/[[:space:]]/, "", $1)
			gsub(/[[:space:]]/, "", $2)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3)
			if ($1 == g && $2 == r) print $3
		}
	' "$CONF"
}

# The UTI this bundle declares for an extension macOS has no real type for.
declared_uti() { printf '%s.%s' "$BUNDLE_ID" "$1"; }

[[ -r "$CONF" ]] || die "cannot read $CONF"
GROUPS_ALL=$(conf_groups)
[[ -n "$GROUPS_ALL" ]] || die "no groups found in $CONF"

register=false
register_groups=(data)
if [[ "${1:-}" == "--register" ]]; then
	register=true
	shift
	[[ $# -gt 0 ]] && register_groups=("$@")
	for g in "${register_groups[@]}"; do
		grep -qx "$g" <<<"$GROUPS_ALL" ||
			die "unknown group '$g'; known groups: $(tr '\n' ' ' <<<"$GROUPS_ALL")"
	done
fi

# --- build ------------------------------------------------------------------

log "compiling $APP"
mkdir -p "$APP_DIR"
rm -rf "$APP"
osacompile -o "$APP" "$SRC_DIR/nvim-ghostty.applescript"

log "installing shell wrapper"
install -m 0755 "$SRC_DIR/open-in-nvim" "$APP/Contents/Resources/open-in-nvim"

log "patching Info.plist"
plist="$APP/Contents/Info.plist"

# osacompile emits a minimal Info.plist, so most keys need Add rather than Set.
plist_set() { # <key> <type> <value>
	$PLIST_BUDDY -c "Set :$1 $3" "$plist" 2>/dev/null ||
		$PLIST_BUDDY -c "Add :$1 $2 $3" "$plist"
}
plist_add() { $PLIST_BUDDY -c "Add :$1 $2 ${3:-}" "$plist"; }

plist_set CFBundleIdentifier string "$BUNDLE_ID"
plist_set CFBundleName string NvimGhostty
plist_set CFBundleDisplayName string NvimGhostty
plist_set NSHighResolutionCapable bool true

# Declaring a document type is what makes the app selectable as a handler at
# all; without it Finder's "Open With" list never shows it.
$PLIST_BUDDY -c "Delete :CFBundleDocumentTypes" "$plist" 2>/dev/null || true
$PLIST_BUDDY -c "Delete :UTImportedTypeDeclarations" "$plist" 2>/dev/null || true
plist_add CFBundleDocumentTypes array
plist_add UTImportedTypeDeclarations array

doc_index=0
uti_index=0
for group in $GROUPS_ALL; do
	name=$(conf_get "$group" name)
	utis=$(conf_get "$group" uti)
	exts=$(conf_get "$group" ext)
	dyns=$(conf_get "$group" dyn)
	[[ -n "$exts" ]] || die "group '$group' declares no extensions"

	doc="CFBundleDocumentTypes:$doc_index"
	plist_add "$doc" dict
	plist_add "$doc:CFBundleTypeName" string "'${name:-$group}'"
	plist_add "$doc:CFBundleTypeRole" string Editor
	plist_add "$doc:LSHandlerRank" string Alternate

	plist_add "$doc:LSItemContentTypes" array
	i=0
	for uti in $utis; do
		plist_add "$doc:LSItemContentTypes:$i" string "$uti"
		i=$((i + 1))
	done
	# The extensions macOS has no type for are claimed through the UTI this
	# bundle declares for them, so they register like any first-class type.
	for ext in $dyns; do
		plist_add "$doc:LSItemContentTypes:$i" string "$(declared_uti "$ext")"
		i=$((i + 1))
	done

	plist_add "$doc:CFBundleTypeExtensions" array
	i=0
	for ext in $exts; do
		plist_add "$doc:CFBundleTypeExtensions:$i" string "$ext"
		i=$((i + 1))
	done

	# Imported, not exported: these are formats the app consumes, not owns.
	for ext in $dyns; do
		decl="UTImportedTypeDeclarations:$uti_index"
		plist_add "$decl" dict
		plist_add "$decl:UTTypeIdentifier" string "$(declared_uti "$ext")"
		plist_add "$decl:UTTypeDescription" string "'${name:-$group}'"
		plist_add "$decl:UTTypeConformsTo" array
		plist_add "$decl:UTTypeConformsTo:0" string public.plain-text
		if [[ "$group" == source ]]; then
			plist_add "$decl:UTTypeConformsTo:1" string public.source-code
		fi
		plist_add "$decl:UTTypeTagSpecification" dict
		plist_add "$decl:UTTypeTagSpecification:public.filename-extension" array
		plist_add "$decl:UTTypeTagSpecification:public.filename-extension:0" string "$ext"
		uti_index=$((uti_index + 1))
	done

	doc_index=$((doc_index + 1))
done
log "declared $doc_index document type groups, $uti_index imported types"

# Editing Info.plist invalidates osacompile's ad-hoc signature.
log "re-signing bundle"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

log "refreshing Launch Services"
touch "$APP"
"$LSREGISTER" -f "$APP"

# --- register ---------------------------------------------------------------

if [[ "$register" == true ]]; then
	command -v duti >/dev/null 2>&1 ||
		die "duti not found; install it with 'brew install duti' and re-run"

	for group in "${register_groups[@]}"; do
		log "registering group '$group'"
		for uti in $(conf_get "$group" uti); do
			duti -s "$BUNDLE_ID" "$uti" all
		done
		for ext in $(conf_get "$group" dyn); do
			duti -s "$BUNDLE_ID" "$(declared_uti "$ext")" all
		done
		# Belt and braces: extensions whose UTI resolution differs from the
		# above still get pinned by tag.
		for ext in $(conf_get "$group" ext); do
			duti -s "$BUNDLE_ID" ".$ext" all
		done
	done
fi

log "done: $APP"
