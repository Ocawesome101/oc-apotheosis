#!/bin/bash

pull () {
  cd $1
  git pull
  cd ..
}

git pull
pull paragon
pull epitome
pull coreutils
pull manpages
