#!/bin/bash

cd /home/ubuntu/data_muncher

git remote update
if !(git status -uno | grep -q "Your branch is up to date with 'origin/master'.")
then
    git pull
    ./data_processor.rb
    /home/ubuntu/log_alert/updater.sh
fi
mkdir -p /home/ubuntu/coyotl/source/public/data/
cp --preserve ./viz_data.json /home/ubuntu/coyotl/source/public/data/

cd -
