import io
import os
import shutil
import sys
import subprocess
import ruamel.yaml
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from pathlib import Path


def run_command(command):
    p = subprocess.Popen(command,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    return iter(p.stdout.readline, b'')


def run_cli_login():
    _result = run_command(['sonmcli', 'login'])
    _result_list = list(_result)
    return _result_list[2][13:]


def modify_ks_yaml(_keystore, _password, file):
    with open(file, 'r') as stream:
        try:
            _file = ruamel.yaml.round_trip_load(stream, preserve_quotes=True)
            _file['ethereum']['key_store'] = DoubleQuotedScalarString(_keystore)
            _file['ethereum']['pass_phrase'] = DoubleQuotedScalarString(_password)
            with io.open(file, 'w+', encoding='utf8') as outfile:
                ruamel.yaml.round_trip_dump(_file, outfile)
        except ruamel.yaml.YAMLError as exc:
            print(exc)


def modify_worker_yaml(_eth_addr, ip):
    with open('/etc/sonm/worker-default.yaml', 'r') as stream:
        try:
            _file = ruamel.yaml.round_trip_load(stream, preserve_quotes=True)
            _file['hub']['eth_addr'] = DoubleQuotedScalarString(_eth_addr)
            _file['public_ip_addrs'] = [DoubleQuotedScalarString(ip)]
            with io.open('/etc/sonm/worker-default.yaml', 'w+', encoding='utf8') as outfile:
                ruamel.yaml.round_trip_dump(_file, outfile)
        except ruamel.yaml.YAMLError as exc:
            print(exc)


def modify_hub_yaml(_home, ip):
    with open('/etc/sonm/hub-default.yaml', 'r') as stream:
        try:
            _file = ruamel.yaml.round_trip_load(stream, preserve_quotes=True)
            _file['cluster']['announce_endpoint'] = DoubleQuotedScalarString(ip + ':15010')
            _file['cluster']['store']['endpoint'] = DoubleQuotedScalarString(_home + '/.sonm/boltdb')
            with io.open('/etc/sonm/hub-default.yaml', 'w+', encoding='utf8') as outfile:
                ruamel.yaml.round_trip_dump(_file, outfile)
        except ruamel.yaml.YAMLError as exc:
            print(exc)


def prepare_dir(path):
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path))


passwd = sys.argv[1]

home = str(Path.home())

keystore_ = home + '/sonm-keystore/'

prepare_dir(keystore_)
prepare_dir('/root/.sonm/')
prepare_dir(home + '/.sonm/')

modify_ks_yaml(keystore_, passwd, '/etc/sonm/cli.yaml')
modify_ks_yaml(keystore_, passwd, '/etc/sonm/node-default.yaml')
modify_ks_yaml(keystore_, passwd, '/etc/sonm/worker-default.yaml')
modify_ks_yaml(keystore_, passwd, '/etc/sonm/hub-default.yaml')

shutil.copy('/etc/sonm/cli.yaml', home + '/.sonm/cli.yaml')
shutil.copy('/etc/sonm/cli.yaml', '/root/.sonm/cli.yaml')

eth_addr = run_cli_login().decode('utf-8').rstrip()

ip = sys.argv[2]

modify_hub_yaml(home, ip)
modify_worker_yaml(eth_addr, ip)
print('Your ethereum address is ' + eth_addr)