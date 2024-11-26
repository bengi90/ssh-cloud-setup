#!/bin/bash

source .env

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

log "Installing packages..."
apt update
apt install -y \
    libpam-ldap \
    libnss-ldap \
    ldap-utils \
    openssh-server \
    nscd \
    nslcd

log "Configuring LDAP..."
cat > /etc/ldap.conf << EOF
base ${LDAP_BASE_DN}
uri ldap://${LDAP_HOST}
binddn ${LDAP_BIND_DN}
bindpw ${LDAP_BIND_PW}
pam_password md5
ssl start_tls
tls_reqcert never
nss_initgroups_ignoreusers root,ldap,mysqld,mysql,nslcd,openldap,debian-sshd
EOF

log "Configuring NSLCD..."
cat > /etc/nslcd.conf << EOF
uid nslcd
gid nslcd
uri ldap://${LDAP_HOST}
base ${LDAP_BASE_DN}
binddn ${LDAP_BIND_DN}
bindpw ${LDAP_BIND_PW}
ssl start_tls
tls_reqcert never
EOF

log "Configuring NSS..."
cat > /etc/nsswitch.conf << EOF
passwd:         files ldap
group:          files ldap
shadow:         files ldap
gshadow:        files
hosts:          files dns
networks:       files
protocols:      files
services:       files
ethers:         files
rpc:            files
netgroup:       files ldap
sudoers:	      files ldap
EOF

log "Configuring PAM..."
cat > /etc/pam.d/sshd << 'EOF'
# Standard Un*x authentication
auth       required     pam_env.so
# LDAP authentication
auth       requisite    pam_ldap.so try_first_pass minimum_uid=1000

# Account management
account    required     pam_unix.so
account    sufficient   pam_ldap.so
account    required     pam_permit.so

# Session management
session    required     pam_unix.so
session    optional     pam_ldap.so
session    required     pam_limits.so
session    required     pam_mkhomedir.so skel=/etc/skel/ umask=0022

# Password management
password   required     pam_unix.so nullok obscure sha512
password   sufficient   pam_ldap.so
EOF

log "Configuring SSH..."
log "Configuring SSH..."
sed -i '/KbdInteractiveAuthentication/d' /etc/ssh/sshd_config
echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config

sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

sed -i '/ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config

# Limit access to groups
sed -i '/AllowGroups/d' /etc/ssh/sshd_config
echo "AllowGroups $ALLOW_GROUPS" >> /etc/ssh/sshd_config

# Disable root login
sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

# Set trusted ssh ca
sed -i '/TrustedUserCAKeys/d' /etc/ssh/sshd_config
echo "TrustedUserCAKeys /etc/ssh/ca_key.pub" >> /etc/ssh/sshd_config

log "Restarting services..."
systemctl restart nslcd
systemctl restart nscd
systemctl restart ssh

log "Install completed!"
