#!/bin/bash
apt-get install -y python3-pip unzip jq

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

MYIP=$(curl -s ipv4.icanhazip.com)

green=`tput setaf 2`
red=`tput setaf 1`
reset=`tput sgr0`
echo "${green}==============================================="
echo "${green}Please enter PASSWORD for new ethereum account:"
echo "${green}===============================================${reset}"
read passwd < /dev/tty
curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-configure.py | python3 - $passwd $MYIP
actual_user=$(logname)
chown -R $actual_user:$actual_user $KSDIR
systemctl restart sonm-node sonm-hub sonm-worker

ip_blocked=$(curl -sX POST http://isitblockedinrussia.com -H 'Content-Type: application/json' -d '{"host":"'$MYIP'"}' | jq -r '.ips[] | .blocked | length')
if [ "$ip_blocked" != "0" ]; then
    echo "${red}Your ip address is blocked in Russia"
    echo "${red}====================================${reset}"
    exit 1
fi
curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-get-eth.py | python3 - $MYIP

echo "${green}SONM installation successfull.${reset}"