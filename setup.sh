#!/bin/bash

CURRENT_DIR=$(cd "$(dirname "$0")" && pwd)

sudo apt update
sudo apt -y install ansible
ansible-playbook $CURRENT_DIR/ansible/playbook.yml --ask-become-pass

stow stow

chsh -s $(which zsh)