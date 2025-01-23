#!/bin/bash

CURRENT_DIR=$(cd "$(dirname "$0")" && pwd)

sudo apt update
sudo apt -y install ansible

ansible-playbook $CURRENT_DIR/ansible/playbook.yml


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
sudo apt install cmake autoconf automake libtool nasm make pkg-config
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

# android studio
## kvm
sudo apt install cpu-checker && sudo kvm-ok
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo wget -P /usr/local https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2024.1.1.11/android-studio-2024.1.1.11-linux.tar.gz &&
	sudo tar -xvf /usr/local/android-studio-2024.1.1.11-linux.tar.gz -C /usr/local
# sudo apt install android-sdk-platform-tools-common

# pnpm
npm install -g pnpm

# brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ngrok
sudo curl https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | sudo tar xvz -C /usr/bin

# change default shell to zsh
chsh -s $(which zsh)

# dockly
npm install -g dockly

# gcloud
sudo apt-get install apt-transport-https ca-certificates gnupg curl &&
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg &&
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list &&
sudo apt-get update && sudo apt-get install google-cloud-cli
