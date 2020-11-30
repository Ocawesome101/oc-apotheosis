#!/bin/bash

push () {
  cd $1
  git add .
  git commit
  git push
  cd ..
}

push paragon
push epitome
push coreutils
push manpages

git add .
git commit
git push
