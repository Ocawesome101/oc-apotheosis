#!/bin/bash
# setup the repos for dev work after a fresh clone when they aren't on a branch

switch () {
  cd $1
  git checkout master
  cd ..
}

switch paragon
switch coreutils
switch epitome
switch manpages
switch tle
