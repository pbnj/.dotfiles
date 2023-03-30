abbr ls "ls -F"
abbr ll "ls -alFh"

if hash exa 2>/dev/null
	abbr ls "exa -F"
	abbr ll "exa -alFh"
end

abbr rm 'rm -i'
abbr cp 'cp -i'
abbr mv 'mv -i'
abbr grep "grep --color=auto --line-buffered"

# vim
if hash nvim 2>/dev/null
	abbr nv "nvim --server $NVIM --remote"
end
abbr vi "vim --clean"
abbr vp "vim +Projects"
abbr vu "tmux capture-pane -Jp -S- -E- | vim +URLs -"
abbr vf "vim +Files!"
abbr vg "vim +0G"
abbr vgf "vim +GF!"
abbr vgs "vim +GF?!"
abbr vrg "vim +Rg!"

# For quick edits
# shellcheck disable SC2139
abbr dotfiles "$EDITOR $HOME/.dotfiles"

# git
abbr ga "git add"
abbr gc "git commit"
abbr gd "git diff"
abbr gco "git checkout"
abbr gp "git push"
abbr gpull "git pull"
abbr groot "cd (git root)"
abbr gs "git status"
abbr gss "git status --short"

# vault
if hash vault 2>/dev/null
	abbr v vault
	abbr vl vault login -method=okta username=$USER
end

# terraform
if hash terraform 2>/dev/null
	abbr tf terraform
	abbr tfv "terraform validate"
	abbr tff "terraform fmt"
	abbr tfp "terraform plan"
	abbr tfa "terraform apply"
	abbr tfss "terraform state show"
	abbr tfsl "terraform state list"
	abbr tfsr "terraform state list | fzf --multi --reverse --height=20 | xargs -I{} -L1 terraform state rm '{}'"
end

# osx
if test (uname) = "Darwin"
	# enable remote login
	abbr macos_remote_login "sudo systemsetup -getremotelogin && sudo systemsetup -setremotelogin on && sudo systemsetup -getremotelogin"
	# desktop
	abbr macos_desktop_hide "defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
	abbr macos_desktop_show "defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
	# .DS_Store
	abbr macos_dsclean "find ~ -type f -name .DS_Store -exec rm -rf {} \;"
end

# brew
if hash brew 2>/dev/null
	abbr brew "arch -arm64 brew"
	abbr bubu "brew update && brew upgrade && brew cleanup --prune 0"
else if hash apt 2>/dev/null
	set SUDO (which sudo)
	abbr auau "$SUDO apt update && $SUDO apt upgrade -y"
end
