#!/usr/bin/env bash

CARDS_NUM=`nvidia-smi -L | grep UUID | wc -l`

mv /etc/sonm/optimus-default.yaml /etc/sonm/optimus-backup.yaml

echo "sed 's/min_price: 0.01/min_price: `bc -l <<< "scale=2; $CARDS_NUM*$1"`/g' /etc/sonm/optimus-backup.yaml > /etc/sonm/optimus-default.yaml" | bash

sonmcli worker ask-plan purge

service sonm-optimus restart