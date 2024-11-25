#!/bin/bash

# verify all users public keys in home dir
for user_home in /home/*; do
    user=$(basename "$user_home")
    user_pubkey="$user_home/.ssh/id_rsa.pub"

    # if current user has a public key (not signed)
    if [ -f "$user_pubkey" ] && ! grep -q "$(whoami)" "$user_pubkey"; then
        # sign key with CA
        sudo ssh-keygen -s /etc/ssh/ca_key -I "$user" -n "$user" "$user_pubkey"
    fi
done