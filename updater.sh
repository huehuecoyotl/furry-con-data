#!/bin/bash

cd /home/ubuntu/data_muncher

git remote update
if !(git status -uno | grep -q "Your branch is up to date with 'origin/master'.")
then
    git pull
    ./data_processor.rb
fi
mkdir -p /home/ubuntu/coyotl/source/public/data/
cp ./viz_data.json /home/ubuntu/coyotl/source/public/data/

cd -
