#!/bin/bash

# Stop script on error
set -e

echo "=== Starting Deployment ==="

# 1. Install Docker & Docker Compose if not installed (Debian specific)
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Check if key already exists to avoid overwrite prompt or error? 
    # The commands below are safe to rerun usually
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and Enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    echo "Docker installed successfully."
else
    echo "Docker is already installed."
fi

# 2. Check for .env file
if [ ! -f .env ]; then
    echo "WARNING: .env file not found."
    echo "Please ensure .env exists with DASHSCOPE_API_KEY environment variable."
    # We don't exit here, in case the user passed env vars via other means, but it's a good warning.
fi

# 3. Create temp directory if it doesn't exist (host side mapping)
mkdir -p temp_audio

# 4. Stop and Remove existing containers
echo "Stopping existing containers..."
sudo docker compose down --remove-orphans || true

# Prune build cache to fix potential "parent snapshot does not exist" errors
echo "Cleaning docker build cache..."
sudo docker builder prune -f || true

# 5. Build and Start
echo "Building and Starting services..."
# We rely on the .env file being present in the directory. 
# Docker Compose automatically reads .env to substitute variables in docker-compose.yml
sudo docker compose up -d --build --force-recreate

echo "=== Deployment Complete ==="
echo "Service is running at port 8000."
echo "You can view logs with: sudo docker compose logs -f"
