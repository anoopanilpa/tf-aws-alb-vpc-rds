#! /bin/bash

sudo yum -y update
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
IP=$(ifconfig | grep inet | awk -F " " '{print $2}' | head -1)
echo “Hello from $IP” > /var/www/html/index.html