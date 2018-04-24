#!/bin/bash
apt-get install -y python3-pip unzip

if ! [ -x "$(command -v docker)" ]; then
  curl -s https://get.docker.com/ | bash
fi

curl -s https://packagecloud.io/install/repositories/SONM/core/script.deb.sh | bash

apt-get install -y sonm-cli sonm-node sonm-hub sonm-worker

pip3 install ruamel.yaml requests

wget https://docs.sonm.io/status/SONM_MVP_0.3.6_configs.zip
rm -rf /etc/sonm/
KSDIR=~/sonm-keystore
if [  -d "$KSDIR"  ]; then
   mv $KSDIR $KSDIR.$(date +%s)
fi
mkdir /etc/sonm/
unzip -j SONM_MVP_0.3.6_configs.zip -d /etc/sonm/

myip=$(curl -s icanhazip.com)

green=`tput setaf 2`
reset=`tput sgr0`
echo "${green}==============================================="
echo "${green}Please enter PASSWORD for new ethereum account:"
echo "${green}===============================================${reset}"
read passwd < /dev/tty
curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-configure.py | python3 - $passwd $myip
actual_user=$(logname)
chown -R $actual_user:$actual_user sonm-keystore/
systemctl restart sonm-node sonm-hub sonm-worker

echo When you will get test ether on your address, please run following command.
echo ''
echo "curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-create-ask-plan.py | python3"
echo ''
echo This command will create ask-plan.