#!/bin/bash

set -e
set -x
set -o pipefail

tmpdir=$(mktemp -d -t app-interface-XXXXXXXXXX)
echo $tmpdir

git clone git@gitlab.cee.redhat.com:service/app-interface.git $tmpdir

cp -r resources/* $tmpdir/resources/

cd $tmpdir

echo -n "Enter a new branch name and press [ENTER] (will be prefixed with synchronize_): "
read branchname

echo -n "Enter a environment name and press [ENTER] (e.g stage, production): "
read environment

branch="synchronize_${branchname}_${environment}"

git checkout -b $branch

git add resources/*-${environment}.*

git commit

echo -n "Enter your fork URL to push to and press [ENTER] (e.g: git@gitlab.cee.redhat.com:USERNAME/app-interface.git): "
read fork

git push $fork $branch

rm -rf $tmpdir
