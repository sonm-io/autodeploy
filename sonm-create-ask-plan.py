import io
import json
import subprocess

from ruamel.yaml import ruamel


def execute_command(_command):
    _command.append('--out=json')
    _result = run_command(_command)
    _result_list = list(_result)
    return json.loads(_result_list[0].decode('utf-8'))


def run_command(command):
    p = subprocess.Popen(command,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    return iter(p.stdout.readline, b'')


def create_slot_yaml(_cpu, _ram):
    try:
        _data = {"duration": "168h",
                 "resources": {"cpu_cores": _cpu, "ram_bytes": _ram, "gpu_count": "NO_GPU", "storage": "256mb",
                               "network": {"in": "1Gb", "out": "1Gb", "type": "INCOMING"},
                               "properties": {"operation-a": 1}}}
        with io.open('slot.yaml', 'w+', encoding='utf8') as outfile:
            ruamel.yaml.round_trip_dump(_data, outfile)
    except ruamel.yaml.YAMLError as exc:
        print(exc)


worker_list = execute_command(['sonmcli', 'hub', 'worker', 'list'])

ask_plan_list = execute_command(['sonmcli', 'hub', 'ask-plan', 'list'])

if 'slots' in ask_plan_list:
    for slot in ask_plan_list['slots']:
        execute_command(['sonmcli', 'hub', 'ask-plan', 'remove', slot])

for worker_id in worker_list['info']:
    status = execute_command(['sonmcli', 'hub', 'worker', 'status', worker_id])
    cpu = len(status['capabilities']['cpu'])
    ram = status['capabilities']['mem']['total']
    create_slot_yaml(cpu, ram)
    execute_command(
        ['sonmcli', 'hub', 'ask-plan', 'create', '0.00001', 'slot.yaml', '0xF03e9f834CEdfCa66781643A04738794870AAd32'])
