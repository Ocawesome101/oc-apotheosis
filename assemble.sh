#!/bin/bash
# assemble all the parts of Apotheosis into a single place.

set -e

GRN="\e[94m::\e[39m"
YLW="\e[93m::\e[39m"
RED="\e[91m::\e[39m"

BUILD_OPTS="-d"
UPDATE=
OCVM=
KVER="0.8.7"
IVER="0.8.0"
export KERNEL_VERSION="$KVER-dev"
export INIT_VERSION="$IVER-dev"
while [ "$1" ]; do
  case "$1" in
    release)
      export KERNEL_VERSION="$KVER"
      export INIT_VERSION="$IVER"
      ;;
    update)
      UPDATE="yes"
      ;;
    ocvm)
      OCVM="yes"
      ;;
    manual)
      BUILD_OPTS=""
      ;;
  esac
  shift
done

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
  lua build.lua $BUILD_OPTS
  cd ..
}

log $GRN "Building Apotheosis"

rm -rf build
mkdir -p build

if [ "$UPDATE" ]; then
  log $GRN "Updating sources"
  git submodule update --remote
  git pull
  update paragon
  update epitome
  update coreutils
  update manpages
  shift
fi

log $GRN "Building Paragon kernel"
build paragon
log $GRN "Building Epitome init"
build epitome
# coreutils and manpages require no building at this time

log $GRN "Assembling"
log $YLW "Apotheosis coreutils -> build"
cp -r coreutils/* build/
mkdir -p build/boot
log $YLW "init.lua -> build"
cp paragon/init.lua build/init.lua
log $YLW "Paragon kernel -> build"
cp paragon/build/kernel.lua build/boot/paragon
log $YLW "initfs image -> build"
cp paragon/build/pinitfs.img build/pinitfs.img
log $YLW "Epitome init -> build"
cp -r epitome/build/* build/
log $YLW "manual pages -> build"
mkdir -p build/usr/man/
cp -r manpages/man/* build/usr/man/
log $GRN "Done."

log $RED "Run 'genfstab' under Apotheosis to generate an fstab."

if [ "$OCVM" ]; then
  ocvm ..
fi
