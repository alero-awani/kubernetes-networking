#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Incorrect args. Usage: $0 <interface>"
    exit 1
fi
sudo tshark -f "not port 22" -i $1 -T fields \
    -e frame.protocols \
    -e ip.src \
    -e ip.dst \
    -E header=y \
