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
push tle

git add .
git commit
git push
