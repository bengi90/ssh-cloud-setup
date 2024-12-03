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
apt-add-repository ppa:ansible/ansible
apt update
apt install -y \
    libpam-ldap \
    libnss-ldap \
    ldap-utils \
    openssh-server \
    nscd \
    nslcd \
    ansible

log "Configuring LDAP..."
cat > /etc/ldap.conf << EOF
base ${LDAP_BASE_DN}
uri ${LDAP_HOST}
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
uri ${LDAP_HOST}
base ${LDAP_BASE_DN}
binddn ${LDAP_BIND_DN}
bindpw ${LDAP_BIND_PW}
map     passwd          uid             sAMAccountName
map     passwd          gecos           displayName
map     passwd          loginShell      "/bin/bash"
ssl start_tls
tls_reqcert never
EOF

log "Configuring NSS..."
sed -i 's/passwd:.*$/passwd: compat ldap/' /etc/nsswitch.conf
sed -i 's/group:.*$/group: compat ldap/' /etc/nsswitch.conf
sed -i 's/shadow:.*$/shadow: compat ldap/' /etc/nsswitch.conf

log "Configuring PAM..."
# Configura il file /etc/pam.d/common-auth
cat << EOF > /etc/pam.d/common-auth
auth       required     pam_env.so
auth       requisite    pam_ldap.so try_first_pass minimum_uid=1000
EOF

# Configura il file /etc/pam.d/common-account
cat << EOF > /etc/pam.d/common-account
account    required     pam_unix.so
account    sufficient   pam_ldap.so
account    required     pam_permit.so
EOF

# Configura il file /etc/pam.d/common-session
cat << EOF > /etc/pam.d/common-session
session    required     pam_unix.so
session    optional     pam_ldap.so
session    required     pam_limits.so
session    required     pam_mkhomedir.so skel=/etc/skel/ umask=0022
EOF

# Configura il file /etc/pam.d/common-password
cat << EOF > /etc/pam.d/common-password
password   required     pam_unix.so nullok obscure sha512
password   sufficient   pam_ldap.so
EOF

log "Configuring SSH..."
sed -i '/KbdInteractiveAuthentication/d' /etc/ssh/sshd_config
echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config

sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

sed -i '/ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config

# Limit access to groups
sed -i '/AllowGroups/d' /etc/ssh/sshd_config
echo "AllowGroups $ALLOW_GROUPS" >> /etc/ssh/sshd_config

# Disable root login
sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config

log "Setting up ssh keys auto-generation"
cat << 'EOF' > /etc/profile.d/ssh-keygen.sh
#!/bin/bash
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
fi
EOF

log "Generating bastion CA"
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ca_key

log "Restarting services..."
systemctl restart nslcd
systemctl restart nscd
systemctl restart ssh

log "Configuring password-less sudo for sudo group"
sed -i 's/%sudo.*$/%sudo	ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

log "Install completed!"