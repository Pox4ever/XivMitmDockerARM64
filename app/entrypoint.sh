#!/bin/bash

# Clean up old iptables-legacy rules
/app/cleanup.sh

DEVICE_NAME=$(ip route get 8.8.8.8 | awk -- '{printf $5}')

# Local Interface
if [ -z ${LOCAL+x} ] || [ "$LOCAL" = "true" ]; then
    for i in $(ip addr show $DEVICE_NAME | grep "inet\b" | awk '{print $2}'); do
        while IFS="" read -r SERVER_IP || [ -n "$SERVER_IP" ]; do
            iptables-legacy -t nat -A POSTROUTING -s $i -d $SERVER_IP -o $DEVICE_NAME -j MASQUERADE
        done < server-list.txt
    done
else
    if [ "$LOCAL" = "false" ]; then
        echo "Not using in LAN."
    fi
fi

# VPN Interface
if [ -z ${VPN+x} ]; then
    echo "No VPN set."
else
    if [ "$VPN" = "true" ]; then
        for var in "${!VPN_INTERFACE_@}"; do
            VPN_SUBNET=$(ip addr show ${!var} | grep "inet\b" | awk '{print $2}')
            
            while IFS="" read -r SERVER_IP || [ -n "$SERVER_IP" ]; do
                iptables-legacy -t nat -A POSTROUTING -s $VPN_SUBNET -d $SERVER_IP -o $DEVICE_NAME -j MASQUERADE
            done < server-list.txt
            iptables-legacy -A FORWARD -i $DEVICE_NAME -o ${!var} -m state --state RELATED,ESTABLISHED -j ACCEPT
            iptables-legacy -A FORWARD -i ${!var} -o $DEVICE_NAME -j ACCEPT
        done
    fi
fi

# Running mitigate.py
if [ -z ${MITIGATOR+x} ] || [ "$MITIGATOR" = "true" ]; then
    # curl https://raw.githubusercontent.com/Soreepeong/XivMitmLatencyMitigator/main/mitigate.py | exec python3 - -u -m &
    curl https://raw.githubusercontent.com/Pox4ever/XivMitmDockerARM64/main/app/mitigation.py | exec python3 - -u -m &
else
    if [ "$MITIGATOR" = "false" ]; then
        echo "XivMitmLatencyMitigator is disabled."
    fi
fi

# SIGTERM
cleanup() {
    /app/cleanup.sh
    exit
}

trap cleanup INT TERM

while :; do
    sleep 1s
done
