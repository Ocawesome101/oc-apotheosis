#!/bin/bash

commit () {
  cd $1
  git add .
  git commit
  cd ..
}

commit paragon
commit epitome
commit coreutils
commit manpages

git add .
git commit
