#!/bin/bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

OPTIMUS_MIN_PRICE=$(cat /etc/sonm/optimus-default.yaml | grep min_price | awk '{print $2}')
if [ -z $(echo $OPTIMUS_MIN_PRICE) ]; then
    OPTIMUS_MIN_PRICE="0.0001"
fi

MASTER_ADDRESS=$1
DEV=$2
github_url='https://raw.githubusercontent.com/sonm-io/autodeploy'
worker_config="worker-default.yaml"
node_config="node-default.yaml"
cli_config="cli.yaml"
optimus_config="optimus-default.yaml"
if [ ${DEV} ]; then
    echo Installing SONM dev packages
    rm  -f /etc/apt/sources.list.d/SONM_core.list
    branch='dev'
    download_url='https://packagecloud.io/install/repositories/SONM/core-dev/script.deb.sh'
else
    echo Installing SONM packages
    rm  -f /etc/apt/sources.list.d/SONM_core-dev.list
    branch='master'
    download_url='https://packagecloud.io/install/repositories/SONM/core/script.deb.sh'
fi
if [ ${SUDO_USER} ]; then actual_user=${SUDO_USER}; else actual_user=$(whoami); fi
actual_user_home=$(eval echo ~${actual_user})

cleanup() {
    rm -f *_template.yaml
    rm -f variables.txt
}


validate_master() {
    if ! [[ ${MASTER_ADDRESS} =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "Given address: '${MASTER_ADDRESS}' is not a valid ethereum address"
        exit 1
    fi
}

install_docker() {
    if ! [ -x "$(command -v docker)" ]; then
        curl -s https://get.docker.com/ | bash
    fi
}

install_dependencies() {
    apt-get update
    apt-get install -y software-properties-common
    if ! [ -z "$(lsb_release -a | grep Ubuntu)" ]; then
    echo "Ubuntu"
        add-apt-repository universe
        apt-get update
    else
        echo "Not Ubuntu"
    fi
    apt-get install -y gnupg apt-transport-https gawk

    declare -a deps=("jq" "curl" "wget")
    for dep in "${deps[@]}"
    do
        if ! [ $(which $dep) ]; then
            to_install="$to_install $dep"
        fi
    done
    if [ -n "$to_install" ]; then
        apt-get install -y ${to_install}
    fi
}

install_sonm() {
    gpg_key_url="https://packagecloud.io/SONM/core/gpgkey"
    apt_config_url="https://packagecloud.io/install/repositories/SONM/core/config_file.list?os=ubuntu&dist=xenial&source=script"
    apt_source_path="/etc/apt/sources.list.d/SONM_core.list"
    curl -sSf "${apt_config_url}" > ${apt_source_path}
    echo -n "Importing packagecloud gpg key... "
    # import the gpg key
    curl -L "${gpg_key_url}" 2> /dev/null | apt-key add - &>/dev/null
    echo "done."

    echo -n "Running apt-get update... "
    apt-get update &> /dev/null
    echo "done."
    apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -y sonm-cli sonm-node sonm-worker sonm-optimus
    echo "Sonm packages installed"
}

download_templates() {
    echo "Downloading templates..."
    wget -q ${github_url}/${branch}/worker_template.yaml -O worker_template.yaml
    wget -q ${github_url}/${branch}/node_template.yaml -O node_template.yaml
    wget -q ${github_url}/${branch}/cli_template.yaml -O cli_template.yaml
    wget -q ${github_url}/${branch}/optimus_template.yaml -O optimus_template.yaml
    wget -q ${github_url}/${branch}/variables.txt -O variables.txt
    echo "Templates downloaded"
}

load_variables() {
    echo "Loading variables..."
    source ./variables.txt
    export $(cut -d= -f1 variables.txt)
    echo "Variables loaded"
}

var_value() {
    eval echo \$$1
}

modify_config() {
    template="${1}"

    vars=$(grep -oE '\{\{[A-Za-z0-9_]+\}\}' "${template}" | sort | uniq | sed -e 's/^{{//' -e 's/}}$//')

    replaces=""
    vars=$(echo $vars | sort | uniq)
    for var in ${vars}; do
        value=$(var_value ${var} | sed -e "s;\&;\\\&;g" -e "s;\ ;\\\ ;g")
        value=$(echo "$value" | sed 's/\//\\\//g');
        replaces="-e \"s|{{$var}}|${value}|g\" $replaces"
    done

    escaped_template_path=$(echo ${template} | sed 's/ /\\ /g')
    eval sed ${replaces} "${escaped_template_path}" > $2
}

resolve_gpu() {
    if [[ $(lsmod | grep amdgpu) ]]; then
        GPU_TYPE="radeon: {}"
        GPU_SETTINGS="gpus:"
        echo detected RADEON GPU
    elif [[ $(lsmod | grep nvidia) ]]; then
        GPU_TYPE="nvidia: {}"
        GPU_SETTINGS="gpus:"
        echo detected NVIDIA GPU
        echo check nvidia-modprobe...
        if ! [ -x "$(command -v nvidia-modprobe)" ]; then
            apt-get install -y nvidia-modprobe
        fi
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
            if [[ $(ls ${WORKER_KEY_PATH}/) ]]; then
                keystore_file=$(ls ${WORKER_KEY_PATH})
                break
            fi
        fi
    done
    WORKER_ADDRESS=0x$(cat ${WORKER_KEY_PATH}/$keystore_file | jq '.address' | sed -e 's/"//g')
}

get_password() {
    if [ -f "$actual_user_home/.sonm/$cli_config" ]
    then
        PASSWORD=$(cat $actual_user_home/.sonm/$cli_config | grep pass_phrase | cut -c16- | awk '{gsub("\x22","\x5C\x5C\x5C\x22");gsub("\x27","\x5C\x5C\x5C\x27"); print}')
    fi
}

set_up_cli() {
    echo setting up cli...
    get_password
    modify_config "cli_template.yaml" ${cli_config}
    mkdir -p ${KEYSTORE}
    mkdir -p ${actual_user_home}/.sonm/
    mv ${cli_config} ${actual_user_home}/.sonm/${cli_config}
    chown -R ${actual_user}:${actual_user} ${KEYSTORE}
    chown -R ${actual_user}:${actual_user} ${actual_user_home}/.sonm
    su ${actual_user} -c "sonmcli login --password=sonm"
    sleep 1
    ADMIN_ADDRESS=$(su ${actual_user} -c "sonmcli login | grep 'Default key:' | cut -c14-56" | tr -d '\r')
    chmod -R 755 ${KEYSTORE}/*
    get_password
}

set_up_node() {
    echo setting up node...
    modify_config "node_template.yaml" ${node_config}
    mv ${node_config} /etc/sonm/${node_config}
}

set_up_worker() {
    echo setting up worker...
    modify_config "worker_template.yaml" ${worker_config}
    mv ${worker_config} /etc/sonm/${worker_config}
}

set_up_optimus() {
    echo setting up optimus...
    modify_config "optimus_template.yaml" ${optimus_config}
    mv ${optimus_config} /etc/sonm/${optimus_config}
}

validate_master
install_dependencies
install_docker
resolve_gpu
install_sonm
download_templates
load_variables

#cli
set_up_cli

#node
set_up_node
#worker
set_up_worker


echo starting node, worker and optimus
systemctl restart sonm-worker sonm-node
#confirm worker
resolve_worker_key
echo "worker address ${WORKER_ADDRESS}"
echo "Switching to worker"
su ${actual_user} -c "sonmcli worker switch ${WORKER_ADDRESS}@127.0.0.1:15010"
set_up_optimus
systemctl restart sonm-optimus
