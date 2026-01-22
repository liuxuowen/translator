#!/bin/bash

# Stop script on error
set -e

# Configuration
SERVER_IP="47.129.9.175"
PEM_KEY="./key.pem"
USER="admin"
REMOTE_DIR="/home/$USER/translator_demo"

# Check PEM
if [ ! -f "$PEM_KEY" ]; then
    echo -e "\033[31mError: key.pem not found at $PEM_KEY!\033[0m"
    exit 1
fi

# Ensure PEM has correct permissions (critical for macOS/Linux ssh)
chmod 400 "$PEM_KEY"

echo -e "\033[36mCreating remote directory...\033[0m"
ssh -i "$PEM_KEY" -o StrictHostKeyChecking=no "$USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

echo -e "\033[36mUploading files...\033[0m"
# List of files to upload
FILES=("app.py" "Dockerfile" "docker-compose.yml" "requirements.txt" ".env", "deploy.sh", "templates", "Caddyfile")

# Construct scp command
# To keep it simple and robust, we pass the files directly if they exist
# Using a loop or checking existence is good practice, but passing multiple args to scp works if they exist.
# We'll stick to a simple scp command for the known list.

scp -i "$PEM_KEY" -r "${FILES[@]}" "$USER@$SERVER_IP:$REMOTE_DIR/"

echo -e "\033[32mRunning deployment on server...\033[0m"
ssh -i "$PEM_KEY" "$USER@$SERVER_IP" "cd $REMOTE_DIR && chmod +x deploy.sh && ./deploy.sh"

echo -e "\033[33mDone! Access your app at http://$SERVER_IP:8000\033[0m"
