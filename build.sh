#!/bin/bash
# assemble all the parts of Apotheosis into a single place.

set -e

GRN="\e[94m::\e[39m"
YLW="\e[93m::\e[39m"
RED="\e[91m::\e[39m"

log () {
  printf "$1 $2\n"
}

update() {
  cd $1
  git pull
  cd ..
}

build () {
  cd $1
  # to manually configure modules, remove the `-d' from this line.
  lua build.lua -d
  cd ..
}

log $GRN "Building Apotheosis"

rm -rf build
mkdir -p build

log $GRN "Updating sources"
update paragon
update epitome
update coreutils

log $GRN "Building Paragon kernel"
build paragon
log $GRN "Building Epitome init"
build epitome
# coreutils requires no building at this time

log $GRN "Assembling"
log $YLW "Apotheosis coreutils -> build"
cp -r coreutils/* build/
mkdir -p build/boot
log $YLW "Paragon kernel -> build"
cp paragon/build/kernel.lua build/boot/paragon
log $YLW "initfs image -> build"
cp paragon/build/pinitfs.img build/pinitfs.img
log $YLW "Epitome init -> build"
cp -r epitome/build/* build/
log $GRN "Done."
