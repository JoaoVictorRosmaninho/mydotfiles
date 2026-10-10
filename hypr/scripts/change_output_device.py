#!/usr/bin/env python

import subprocess
import json

audio_devices_list_command   = 'pactl --format=json list sinks'.split()
wofi_selector_menu_command   = 'wofi -p OutputSelector --dmenu'.split()
audio_devices_change_command = 'pactl set-default-sink'


def audio_devices_change_command_builder(device_id) -> list:
    return  (audio_devices_change_command + ' ' + str(device_id)).split()   
    
def select_output_device():
    result                     = subprocess.run(audio_devices_list_command, capture_output=True, text=True, check=True)

    audio_devices_str          = result.stdout.strip()

    audio_devices_map          = json.loads(audio_devices_str);

    audio_devices_map          = list(filter(lambda item: "output" in item['name'] and item['properties']['media.class'] == "Audio/Sink", audio_devices_map))

    audio_devices              = list(map(lambda item: (item['properties']['device.description'], item['index']), audio_devices_map))

    audio_devices_map          = dict(audio_devices)

    wofi_subprocessor          = subprocess.run(wofi_selector_menu_command, capture_output=True, text=True, input="\n".join(list(audio_devices_map.keys())))

    wofi_subprocessor_result   = wofi_subprocessor.stdout.strip()

    device_id                  = audio_devices_map[wofi_subprocessor_result]

    # changing the device to the one that has the id device_id
    change_output_command_list = audio_devices_change_command_builder(device_id)

    subprocess.run(change_output_command_list)

def main():

    #if wofi and pactl are installed then
    if subprocess.run(['which', 'wofi'], capture_output=True).returncode == 0 and subprocess.run(['which', 'pactl'], capture_output=True).returncode == 0:
        select_output_device()
    else:
        print("wofi or pactl is not installed")
main()
