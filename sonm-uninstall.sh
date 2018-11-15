#!/usr/bin/env bash

if systemctl is-active sonm-worker; then
    systemctl stop sonm-worker && echo "sonm-worker stopped";
fi
if systemctl is-active sonm-node; then
    systemctl stop sonm-node && echo "sonm-node stopped";
fi
if systemctl is-active sonm-optimus; then
    systemctl stop sonm-optimus && echo "sonm-optimus stopped";
fi
if  [[ $(dpkg --get-selections | grep -v deinstall | grep sonm | awk '{print $1}') ]]; then
    dpkg -P $(dpkg --get-selections | grep -v deinstall | grep sonm | awk '{print $1}')
fi
rm -rf /etc/sonm
rm -rf /var/lib/sonm