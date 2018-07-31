cd /home/ubuntu/data_muncher

if [ git diff --quiet ]
then
    git pull
    ruby data_processor.rb
    cp ./processed_data/* /home/ubuntu/coyotl/source/public/data/
fi
