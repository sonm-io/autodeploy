#!/bin/bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

download_url='https://packagecloud.io/install/repositories/SONM/core/script.deb.sh'
node_config="node-default.yaml"
cli_config="cli.yaml"
if [ $SUDO_USER ]; then actual_user=$SUDO_USER; else actual_user=`whoami`; fi
actual_user_home=$(eval echo ~$actual_user)

cleanup() {
    rm -f *_template.yaml
    rm -f variables.txt
}

install_dependency() {
    apt-get update
    apt-get install -y jq curl wget
}

download_artifacts() {
    curl -s $download_url | bash
    apt-get install -y sonm-cli sonm-node
}

download_templates() {
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

get_password() {
    PASSWORD=$(cat $actual_user_home/.sonm/$cli_config | grep pass_phrase | cut -c16- | sed -e 's/"//g')
}

set_up_cli() {
    echo setting up cli...
    modify_config "cli_template.yaml" $cli_config
    mkdir -p $KEYSTORE
    mkdir -p $actual_user_home/.sonm/
    mv $cli_config $actual_user_home/.sonm/$cli_config
    chown -R $actual_user:$actual_user $KEYSTORE
    chown -R $actual_user:$actual_user $actual_user_home/.sonm
    su - $actual_user -c "sonmcli login"
    sleep 1
    MASTER_ADDRESS=$(su - $actual_user -c "sonmcli login | head -n 1| cut -c14-")
    chmod -R 755 $KEYSTORE/*
}

set_up_node() {
    echo setting up node...
    modify_config "node_template.yaml" $node_config
    mv $node_config /etc/sonm/$node_config
}

install_dependency
download_artifacts
download_templates
load_variables

#cli
set_up_cli
get_password

#node
set_up_node

echo starting node...
systemctl start sonm-node
