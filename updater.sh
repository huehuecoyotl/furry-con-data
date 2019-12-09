#!/bin/bash

cd /home/ubuntu/data_muncher

git pull
./data_processor.rb
cp ./processed_data/* /home/ubuntu/coyotl/source/public/data/

cd -
