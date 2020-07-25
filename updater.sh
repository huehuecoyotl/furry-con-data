#!/bin/bash

cd /home/ubuntu/data_muncher

if !(git pull | grep "Already up to date.")
then
    git pull
    ./data_processor.rb
fi
cp ./processed_data/* /home/ubuntu/coyotl/source/public/data/

cd -
