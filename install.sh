#!/bin/bash

sudo apt update && sudo apt upgrade

# apt packages
sudo apt -y install zsh stow curl xsel

## python require
sudo apt -y install build-essential libbz2-dev libdb-dev \
	libreadline-dev libffi-dev libgdbm-dev liblzma-dev \
	libncursesw5-dev libsqlite3-dev libssl-dev \
	zlib1g-dev uuid-dev tk-dev

## ruby require
sudo apt -y install libyaml-dev unzip

# stow
for dir in */; do
	stow "${dir%/}"
done

# nvim
curl -LO https://github.com/neovim/neovim-releases/releases/download/v0.10.0/nvim-linux64.deb && sudo apt install ./nvim-linux64.deb && rm -f ./nvim-linux64.deb

# mise
[ ! -f "~/.local/bin/mise" ] && curl https://mise.run | sh
mise install -y

# gh (github cli)
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) &&
	sudo mkdir -p -m 755 /etc/apt/keyrings &&
	wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
	sudo apt update &&
	sudo apt install gh -y

# mozjpeg
wget https://github.com/mozilla/mozjpeg/archive/refs/tags/v4.1.1.tar.gz &&
	tar xvzf ./v4.1.1.tar.gz &&
	rm -f v4.1.1.tar.gz &&
	cd mozjpeg-4.1.1 &&
	mkdir build && cd build &&
	sudo cmake -G"Unix Makefiles" -DPNG_SUPPORTED=ON ../ &&
	sudo make install && sudo make deb &&
	sudo dpkg -i mozjpeg_4.1.1_amd64.deb &&
	sudo ln -s /opt/mozjpeg/bin/cjpeg /usr/bin/mozjpeg &&
	sudo ln -s /opt/mozjpeg/bin/jpegtran /usr/bin/mozjpegtran &&
	cd ../../ && sudo rm -rf mozjpeg-4.1.1

# colorls
gem install colorls

chsh -s $(which zsh)
