#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -o errexit

worker_config="worker_default.yaml"
node_config="node_default.yaml"
cli_config="cli.yaml"
actual_user=$(logname)
mkdir -p ~/.sonm/

install_docker() {
	if ! [ -x "$(command -v docker)" ]; then
		curl -s https://get.docker.com/ | bash
	fi
}

install_dependency() {
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
    wget https://raw.githubusercontent.com/sonm-io/autodeploy/master/worker_template.yaml
    wget https://raw.githubusercontent.com/sonm-io/autodeploy/master/node_template.yaml
    wget https://raw.githubusercontent.com/sonm-io/autodeploy/master/cli_template.yaml
    wget https://raw.githubusercontent.com/sonm-io/autodeploy/master/variables.txt
}

load_variables() {
    source variables.txt
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
        GPU_SETTINGS="gpus:\n\\ \\ \\ \\ radeon: {}"
    elif [[ $(lsmod | grep nvidia) ]]; then
        GPU_SETTINGS="gpus:\n\\ \\ \\ \\ nvidia: {}"
    else
        GPU_SETTINGS=""
    fi
}

install_dependency
install_docker
download_artifacts
download_templates
load_variables
read_password

#cli
modify_config "cli_template.yaml" $cli_config
mv $cli_config ~/.sonm/$cli_config
MASTER_ADDRESS=$(sonmcli login | head -n 1| cut -c14-)

#node
modify_config "node_template.yaml" $node_config
mv $node_config /etc/sonm/$node_config

#worker
resolve_gpu
modify_config "worker_template.yaml" $worker_config
mv $worker_config /etc/sonm/$worker_config
systemctl start sonm-worker

keystore_file=$(ls $WORKER_KEY_PATH)
WORKER_ADDRESS=$(cat $WORKER_KEY_PATH/$keystore_file | jq '.address')

#confirm worker
sonmcli master confirm $WORKER_ADDRESS