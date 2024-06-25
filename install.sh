#!/bin/bash

for d in *(/); stow -v -t ~/ -S $d
