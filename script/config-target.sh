#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    error "This script must be executed as root"
fi

if [ -z "$1" ]; then
    log   "Usage: config-target.sh <target_ip_or_hostname>"
    error "Missing required 'target' parameter"
fi

log "Installing bastion CA on the target..."
scp /etc/ssh/ca_key.pub "root@$1:/etc/ssh/ca_key.pub"

log "Installing setup script on the target..."
scp setup-target.sh .env "root@$1:/root/"

log "Running setup script on the target..."
ssh "root@$1" "bash /root/setup-target.sh"

log "Target configured!"
