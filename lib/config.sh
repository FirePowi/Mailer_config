#!/usr/bin/env bash
#
# Configuration Variables
# Shared state across all modules
#

# System detection
DISTRO=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""
SERVICE_MANAGER="systemctl"
SERVER_IP=""

# Installation choices
DOMAINS=()
PRIMARY_DOMAIN=""
HOSTNAME=""
ADMIN_EMAIL=""
ENABLE_SPAMASSASSIN=false
ENABLE_CLAMAV=false
ENABLE_POLICYD_SPF=true
ENABLE_POSTFIXADMIN=true
ENABLE_RSPAMD=false
ENABLE_DKIM=true
WEBMAIL_CHOICE="none"
WEB_SERVER="none" # Will be set to nginx or apache
DB_PASSWORD=""
POSTFIXADMIN_PASSWORD=""
WEBMAIL_PASSWORD=""
VMAIL_UID=5000
VMAIL_GID=5000

# Paths
POSTFIX_DIR="/etc/postfix"
DOVECOT_DIR="/etc/dovecot"
VMAIL_DIR="/var/vmail"
CERTBOT_DIR="/etc/letsencrypt"

# Script directory (set by main installer)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
