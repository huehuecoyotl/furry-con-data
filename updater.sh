#!/bin/bash

cd /home/ubuntu/data_muncher

git remote update
if !(git status -uno | grep -q "Your branch is up to date with 'origin/master'.")
then
    git pull
    ./data_processor.rb
fi
cp ./processed_data/* /home/ubuntu/coyotl/source/public/data/

cd -
