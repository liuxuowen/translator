#!/bin/bash

# Configuration
SERVER_IP="47.129.9.175"
PEM_KEY="/Users/chris/aws_sin.pem"  # Assumes the key is in the same directory. Update this path if your key is elsewhere (e.g., "~/Documents/demo_sin.pem")
USER="admin"

# Check if PEM file exists
if [ ! -f "$PEM_KEY" ]; then
    echo -e "\033[0;31mError: PEM file not found at $PEM_KEY\033[0m"
    echo "Please ensure your key file is named 'demo_sin.pem' and placed in this directory, or update the PEM_KEY variable in this script."
    exit 1
fi

# Ensure correct permissions for the key (Critical for macOS/Linux)
# SSH will reject keys that are too open (e.g. 777 or 644)
chmod 400 "$PEM_KEY"

echo "Connecting to $USER@$SERVER_IP..."
ssh -i "$PEM_KEY" $USER@$SERVER_IP
