#!/bin/bash

# Exit script as soon as a command fails.
set -o errexit

worker_config="worker-default.yaml"
node_config="node-default.yaml"
cli_config="cli.yaml"
actual_user=$(logname)
mkdir -p ~/.sonm/

remove_previous_version() {
    if systemctl is-active sonm-worker; then
        systemctl stop sonm-worker && echo "sonm-worker stopped";
    fi
    if systemctl is-active sonm-node; then
        systemctl stop sonm-node && echo "sonm-node stopped";
    fi
    dpkg -P $(dpkg --get-selections | grep -v deinstall | grep sonm | awk '{print $1}')
    rm -rf /etc/sonm
    rm -rf /var/lib/sonm
}

install_docker() {
    if ! [ -x "$(command -v docker)" ]; then
        curl -s https://get.docker.com/ | bash
    fi
}

install_dependency() {
    apt-get update
    apt-get install -y jq curl wget
}

read_password() {
    green=`tput setaf 2`
    reset=`tput sgr0`
    echo "${green}==============================================="
    echo "${green}Please enter PASSWORD for new ethereum account:"
    echo "${green}===============================================${reset}"
    read PASSWORD < /dev/tty
}

download_artifacts() {
    curl -s https://packagecloud.io/install/repositories/SONM/core/script.deb.sh | bash
    apt-get install -y sonm-cli sonm-node sonm-worker
}

download_templates() {
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/worker_template.yaml -O worker_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/node_template.yaml -O node_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/cli_template.yaml -O cli_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/variables.txt -O variables.txt
}

load_variables() {
    echo loading variables...
    source ./variables.txt
    export $(cut -d= -f1 variables.txt)
}

var_value() {
    eval echo \$$1
}

modify_config() {
    template="${1}"

    vars=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "${template}" | sort | uniq | sed -e 's/^{{//' -e 's/}}$//')

    replaces=""
    vars=$(echo $vars | sort | uniq)
    for var in $vars; do
        value=$(var_value $var | sed -e "s;\&;\\\&;g" -e "s;\ ;\\\ ;g")
        value=$(echo "$value" | sed 's/\//\\\//g');
        replaces="-e 's|{{$var}}|${value}|g' $replaces"
    done

    escaped_template_path=$(echo $template | sed 's/ /\\ /g')
    eval sed $replaces "$escaped_template_path" > $2
}

resolve_gpu() {
    if [[ $(lsmod | grep amd) ]]; then
        GPU_TYPE="radeon: {}"
        GPU_SETTINGS="gpus:"
        echo detected RADEON GPU
    elif [[ $(lsmod | grep nvidia) ]]; then
        GPU_TYPE="nvidia: {}"
        GPU_SETTINGS="gpus:"
        echo detected NVIDIA GPU
    else
        GPU_SETTINGS=""
        GPU_TYPE=""
        echo no GPU detected
    fi
}

resolve_worker_key() {
    x=0
    while [ "$x" -lt 100 ]; do
        x=$((x+1))
        sleep .1
        if [[ $(ls $WORKER_KEY_PATH/) ]]; then
            keystore_file=$(ls $WORKER_KEY_PATH)
            break
        fi
    done
    WORKER_ADDRESS=$(cat $WORKER_KEY_PATH/$keystore_file | jq '.address')
}

remove_previous_version
install_dependency
install_docker
download_artifacts
download_templates
load_variables
read_password

#cli
echo setting up cli...
modify_config "cli_template.yaml" $cli_config
mv $cli_config ~/.sonm/$cli_config
mkdir -p $KEYSTORE
chown -R $actual_user:$actual_user $KEYSTORE
chown -R $actual_user:$actual_user ~/.sonm
su - $actual_user -c "sonmcli login"
MASTER_ADDRESS=$(su - $actual_user -c "sonmcli login | head -n 1| cut -c14-")
chmod +r $KEYSTORE/*

#node
echo setting up node...
modify_config "node_template.yaml" $node_config
mv $node_config /etc/sonm/$node_config

#worker
echo setting up worker...
resolve_gpu
modify_config "worker_template.yaml" $worker_config
mv $worker_config /etc/sonm/$worker_config

echo starting node and worker

systemctl start sonm-worker sonm-node

echo "wait for confirm worker"
resolve_worker_key

#confirm worker
su - $actual_user -c "sonmcli master confirm $WORKER_ADDRESS"