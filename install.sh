#!/bin/bash

# stow
for dir in */; do
  stow "${dir%/}"
done


# apt packages
PACKAGE_LIST="apt-packages.txt"
if [[ -s $PACKAGE_LIST ]]; then
  while IFS= read -r package; do
    if ! dpkg -l | grep -q "^ii  $package"; then
      sudo apt install -y "$package"
    else
      echo "$package is already installed."
    fi
  done < "$PACKAGE_LIST"
else
  echo "$PACKAGE_LIST not found!"
fi

# check version manager

## nvm
[ ! -s "$NVM_DIR/nvm.sh" ] && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

## pyenv
[ ! -s "$PYENV_ROOT" ] && curl https://pyenv.run | bash


# setup version manager

source $HOME/.bashrc

## nvm
if [ -z "$NODE_VERSION" ]; then
  nvm install --lts && nvm use --lts
else
  nvm install $NODE_VERSION && nvm use $NODE_VERSION
fi

## pyenv
if [ -z "$PYTHON_VERSION" ]; then
  pyenv install 3:latest && pyenv global 3
else
  pyenv install $PYTHON_VERSION && pyenv global $PYTHON_VERSION
fi



# bun
export BUN_INSTALL="$HOME/.bun"
[ ! -s "$BUN_INSTALL" ] && curl -fsSL https://bun.sh/install | bash -s "bun-v1.0.0"
export PATH=$BUN_INSTALL/bin:$PATH

# colorls
if ! gem list -i colorls > /dev/null 2>&1; then
  echo "colorls not found. Installing..."
  sudo gem install colorls
else
  echo "colorls is already installed."
fi
source $(dirname $(gem which colorls))/tab_complete.sh


chsh -s $(which zsh)