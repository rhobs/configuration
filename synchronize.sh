#!/bin/bash

set -e
set -x
set -o pipefail

tmpdir=$(mktemp -d -t app-interface-XXXXXXXXXX)
echo $tmpdir

git clone git@gitlab.cee.redhat.com:service/app-interface.git $tmpdir

cp -r resources/* $tmpdir/resources/

cd $tmpdir

echo -n "Enter a new branch name and press [ENTER]: "
read branchname

branch="synchronize-${branchname}"

git checkout -b $branch

git add resources/

git commit

echo -n "Enter your fork URL to push to and press [ENTER]: "
read fork

git push $fork $branch

rm -rf $tmpdir
