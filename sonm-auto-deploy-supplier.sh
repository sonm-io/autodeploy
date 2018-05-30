#!/bin/bash

# Exit script as soon as a command fails.
set -o errexit
download_url='https://packagecloud.io/install/repositories/SONM/core/script.deb.sh'
worker_config="worker-default.yaml"
node_config="node-default.yaml"
cli_config="cli.yaml"
optimus_config="optimus-default.yaml"
actual_user=$(logname)

install_docker() {
    if ! [ -x "$(command -v docker)" ]; then
        curl -s https://get.docker.com/ | bash
    fi
}

install_dependency() {
    apt-get update
    apt-get install -y jq curl wget
}

download_artifacts() {
    curl -s $download_url | bash
    apt-get install -y sonm-cli sonm-node sonm-worker sonm-optimus
}

download_templates() {
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/worker_template.yaml -O worker_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/node_template.yaml -O node_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/cli_template.yaml -O cli_template.yaml
    wget -q https://raw.githubusercontent.com/sonm-io/autodeploy/master/optimus_template.yaml -O optimus_template.yaml
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
    while [ "$x" -lt 300 ]; do
        x=$((x+1))
        sleep .1
        if [ -d "${WORKER_KEY_PATH}" ]; then
            if [[ $(ls $WORKER_KEY_PATH/) ]]; then
                keystore_file=$(ls $WORKER_KEY_PATH)
                break
            fi
        fi
    done
    WORKER_ADDRESS=0x$(cat $WORKER_KEY_PATH/$keystore_file | jq '.address' | sed -e 's/"//g')
}

get_password() {
     PASSWORD=$(cat /home/$actual_user/.sonm/$cli_config | grep pass_phrase | cut -c16- | sed -e 's/"//g')
}

set_up_cli() {
    echo setting up cli...
    modify_config "cli_template.yaml" $cli_config
    mkdir -p $KEYSTORE
    mkdir -p /home/$actual_user/.sonm/
    mv $cli_config /home/$actual_user/.sonm/$cli_config
    chown -R $actual_user:$actual_user $KEYSTORE
    chown -R $actual_user:$actual_user /home/$actual_user/.sonm
    su - $actual_user -c "sonmcli login"
    sleep 1
    MASTER_ADDRESS=$(su - $actual_user -c "sonmcli login | head -n 1| cut -c14-")
    chmod +r $KEYSTORE/*
}

set_up_node() {
    echo setting up node...
    modify_config "node_template.yaml" $node_config
    mv $node_config /etc/sonm/$node_config
}

set_up_worker() {
    echo setting up worker...
    resolve_gpu
    modify_config "worker_template.yaml" $worker_config
    mv $worker_config /etc/sonm/$worker_config
}

set_up_optimus() {
    echo setting up optimus...
    modify_config "optimus_template.yaml" $optimus_config
    mv $optimus_config /etc/sonm/$optimus_config
}

install_dependency
install_docker
download_artifacts
download_templates
load_variables

#cli
set_up_cli
get_password

#node
set_up_node
#worker
set_up_worker


echo starting node, worker and optimus
systemctl start sonm-worker sonm-node
#confirm worker
echo "wait for confirm worker"
resolve_worker_key
sleep 10
echo "worker address ${WORKER_ADDRESS}"
echo "if you have error like '[ERR] Cannot approve Worker's request', please run following commands later:"
echo "sonmcli master confirm ${WORKER_ADDRESS}"
echo "sonmcli worker switch ${WORKER_ADDRESS}@127.0.0.1:15010"
su - $actual_user -c "sonmcli master confirm $WORKER_ADDRESS"
su - $actual_user -c "sonmcli worker switch $WORKER_ADDRESS@127.0.0.1:15010"

set_up_optimus
systemctl start sonm-optimus