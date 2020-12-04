#!/bin/bash

pull () {
  cd $1
  git pull
  cd ..
}

git submodule update --remote
git pull
pull paragon
pull epitome
pull coreutils
pull manpages
