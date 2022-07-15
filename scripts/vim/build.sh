#!/bin/bash

set -e
set -x

if command -v apt &>/dev/null; then
	# Removing old packages
	sudo apt-get remove --purge \
		vim \
		vim-gnome \
		vim-gui-common \
		vim-runtime \
		vim-tiny

	# Installing build dependencies
	sudo apt-get install -y \
		libatk1.0-dev \
		liblua5.1-dev \
		libluajit-5.1 \
		libncurses5-dev \
		libperl-dev \
		libx11-dev \
		libxpm-dev \
		libxt-dev \
		luajit \
		python-dev \
		ruby-dev

	#Optional: so vim can be uninstalled again via `dpkg -r vim`
	sudo apt-get install checkinstall
fi

if command -v yum &>/dev/null; then
	sudo yum update
	sudo yum groupinstall 'Development tools'
	sudo yum install -y \
		ctags \
		git \
		lua \
		lua-devel \
		luajit \
		luajit-devel \
		ncurses \
		ncurses-devel \
		perl \
		perl-ExtUtils-CBuilder \
		perl-ExtUtils-Embed \
		perl-ExtUtils-ParseXS \
		perl-ExtUtils-XSpp \
		perl-devel \
		python \
		python-devel \
		python3 \
		python3-devel \
		ruby \
		ruby-devel \
		tcl-devel
fi

sudo rm -rf /usr/local/share/vim /usr/bin/vim

git clone https://github.com/vim/vim "$HOME/vim"
(
	cd "$HOME/vim"
	git pull
	git fetch

	./configure \
		--disable-netbeans \
		--enable-cscope \
		--enable-fail-if-missing \
		--enable-fontset \
		--enable-gui=auto \
		--enable-largefile \
		--enable-luainterp \
		--enable-multibyte \
		--enable-perlinterp=dynamic \
		--enable-python3interp \
		--prefix=/usr/local \
		--with-compiledby="$(whoami)" \
		--with-features=huge \
		--with-luajit \
		--with-tlib=ncurses \
		--without-x

	make
	sudo make install
)
