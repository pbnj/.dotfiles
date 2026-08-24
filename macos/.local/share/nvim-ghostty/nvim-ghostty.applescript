-- NvimGhostty: a document handler that opens files in Neovim inside Ghostty.
--
-- macOS Launch Services can only hand documents to an .app bundle, never to a
-- bare CLI binary, so this script exists purely to receive the `odoc` Apple
-- event from Finder and forward each path to the shell wrapper in
-- Contents/Resources.

on open theFiles
	set wrapper to quoted form of (POSIX path of (path to resource "open-in-nvim"))
	repeat with f in theFiles
		do shell script wrapper & " " & quoted form of (POSIX path of f)
	end repeat
end open

-- Double-clicking the app itself (no documents) just opens an empty editor.
on run
	set wrapper to quoted form of (POSIX path of (path to resource "open-in-nvim"))
	do shell script wrapper
end run
