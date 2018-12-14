#!/bin/sh

#
# This script is part of cocoasudo

builddir=/tmp/cocoasudo.build
workdir=/tmp/cocoasudo
symroot="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"/..           # Manage-Conky dir location

##
## BEAUTIFY
##
bold=$(tput bold)
echo "${bold}DistributeCocoasudo.command | version 1.0 | by npyl"
echo "\n"

# remove any previous files...
rm -rf "$builddir"
rm -rf "$workdir"

# create builddir & workdir
mkdir -p "$builddir"
mkdir -p "$workdir"

# change directory into project root
cd "$symroot"

# build project for RELEASE
xcodebuild -project "cocoasudo.xcodeproj" -scheme "cocoasudo" -configuration "Release" -derivedDataPath "$builddir" -quiet clean build

# copy into workdir
cp -R "$builddir"/Build/Products/Release/cocoasudo.app "$workdir"
cp -R "$symroot"/Resources/InstallCocoasudo.command "$workdir"

# zip it up
cd /tmp
zip -r ~/cocoasudo.zip "cocoasudo"
