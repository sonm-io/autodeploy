import subprocess
import sys

import requests


def run_command(command):
    p = subprocess.Popen(command,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    return iter(p.stdout.readline, b'')


def run_cli_login():
    _result = run_command(['sonmcli', 'login'])
    _result_list = list(_result)
    return _result_list[2][13:]


eth_addr = run_cli_login().decode('utf-8').rstrip()
ip = sys.argv[1]
response = requests.post('http://95.216.141.161:8000/register', json={'addr': eth_addr, 'ip': ip})

if response.status_code != 200:
    print("!!!!! Autorefill failed. Please refill account with ethereum manually !!!!!")
