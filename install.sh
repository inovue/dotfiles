#!/bin/bash

# dotfiles

for i in "$(ls -d */)"; do 
  stow "$i"
done


# apt 

PACKAGE_LIST="apt-packages.txt"

if [[ ! -f $PACKAGE_LIST ]]; then
  echo "$PACKAGE_LIST not found!"
  exit 1
fi

while IFS= read -r package; do
  if ! dpkg -l | grep -q "^ii  $package"; then
    sudo apt install -y $package
  else
    echo "$package is already installed."
  fi
done < "$PACKAGE_LIST"


sodo chsh -s $(which zsh)