#!/bin/bash

cd /home/ubuntu/data_muncher

if git diff --quiet
then
    git pull
    ./data_processor.rb
fi
cp ./processed_data/* /home/ubuntu/coyotl/source/public/data/

cd -
