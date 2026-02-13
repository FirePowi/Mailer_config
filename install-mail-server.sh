#!/usr/bin/env bash
#
# Interactive Mail Server Installation and Configuration Script
# Supports: Postfix, Dovecot, SpamAssassin, Policyd-SPF, Postfixadmin, and more
# Works on: Debian, Ubuntu, RedHat, Fedora, CentOS, Arch Linux, and derivatives
#
# Usage: sudo ./install-mail-server.sh
# No arguments needed - the script will ask questions interactively
#

set -euo pipefail

# ============================================================================
# COLORS AND UI
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================

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

# ============================================================================
# UI FUNCTIONS
# ============================================================================

print_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                       ║"
    echo "║           Interactive Mail Server Installation Script                ║"
    echo "║                                                                       ║"
    echo "║     Postfix + Dovecot + SpamAssassin + Policyd-SPF + More           ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $*"
}

ask_question() {
    local question="$1"
    local default="${2:-}"
    local response
    
    if [[ -n "$default" ]]; then
        echo -e "${YELLOW}${question}${NC} ${WHITE}[${default}]${NC}"
    else
        echo -e "${YELLOW}${question}${NC}"
    fi
    
    read -r response
    echo "${response:-$default}"
}

ask_yes_no() {
    local question="$1"
    local default="${2:-y}"
    local response
    
    if [[ "$default" == "y" ]]; then
        echo -e "${YELLOW}${question}${NC} ${WHITE}[Y/n]${NC}"
    else
        echo -e "${YELLOW}${question}${NC} ${WHITE}[y/N]${NC}"
    fi
    
    read -r response
    response="${response:-$default}"
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

pause_for_user() {
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read -r
}

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

detect_distribution() {
    print_section "Detecting Linux Distribution"
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
        
        case "$DISTRO" in
            ubuntu|debian|linuxmint|pop)
                DISTRO_FAMILY="debian"
                PACKAGE_MANAGER="apt-get"
                ;;
            rhel|centos|fedora|rocky|alma)
                DISTRO_FAMILY="redhat"
                PACKAGE_MANAGER="yum"
                [[ -x "$(command -v dnf)" ]] && PACKAGE_MANAGER="dnf"
                ;;
            arch|manjaro|endeavouros)
                DISTRO_FAMILY="arch"
                PACKAGE_MANAGER="pacman"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="suse"
                PACKAGE_MANAGER="zypper"
                ;;
            *)
                log_error "Unsupported distribution: $DISTRO"
                exit 1
                ;;
        esac
        
        log_success "Detected: $NAME ($DISTRO_FAMILY family)"
        log_info "Package manager: $PACKAGE_MANAGER"
    else
        log_error "Cannot detect distribution - /etc/os-release not found"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Please run: sudo $0"
        exit 1
    fi
}

# ============================================================================
# PACKAGE NAME MAPPING
# ============================================================================

get_package_name() {
    local package="$1"
    
    case "$DISTRO_FAMILY" in
        debian)
            case "$package" in
                postfix) echo "postfix" ;;
                postfix-mysql) echo "postfix-mysql" ;;
                postfix-policyd-spf) echo "postfix-policyd-spf-python" ;;
                dovecot) echo "dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd" ;;
                dovecot-mysql) echo "dovecot-mysql" ;;
                mysql-server) echo "mariadb-server" ;;
                mysql-client) echo "mariadb-client" ;;
                spamassassin) echo "spamassassin spamc" ;;
                clamav) echo "clamav clamav-daemon" ;;
                certbot) echo "certbot python3-certbot-apache" ;;
                opendkim) echo "opendkim opendkim-tools" ;;
                rspamd) echo "rspamd" ;;
                postfixadmin) echo "postfixadmin" ;;
                roundcube) echo "roundcube roundcube-mysql" ;;
                sogo) echo "sogo sogo-activesync" ;;
                php) echo "php php-fpm php-mysql php-imap php-mbstring php-json php-xml php-curl" ;;
                nginx) echo "nginx" ;;
                apache) echo "apache2" ;;
                wget) echo "wget" ;;
                unzip) echo "unzip" ;;
                *)
                    log_warning "Unknown package: $package"
                    echo "$package"
                    ;;
            esac
            ;;
        redhat)
            case "$package" in
                postfix) echo "postfix" ;;
                postfix-mysql) echo "postfix-mysql" ;;
                postfix-policyd-spf) echo "postfix-policyd-spf-python" ;;
                dovecot) echo "dovecot dovecot-mysql" ;;
                dovecot-mysql) echo "dovecot-mysql" ;;
                mysql-server) echo "mariadb-server" ;;
                mysql-client) echo "mariadb" ;;
                spamassassin) echo "spamassassin" ;;
                clamav) echo "clamav clamav-update" ;;
                certbot) echo "certbot python3-certbot-apache" ;;
                opendkim) echo "opendkim" ;;
                rspamd) echo "rspamd" ;;
                postfixadmin) echo "postfixadmin" ;;
                roundcube) echo "roundcubemail" ;;
                sogo) echo "sogo sogo-activesync" ;;
                php) echo "php php-fpm php-mysqlnd php-imap php-mbstring php-json php-xml" ;;
                nginx) echo "nginx" ;;
                apache) echo "httpd" ;;
                wget) echo "wget" ;;
                unzip) echo "unzip" ;;
                *)
                    log_warning "Unknown package: $package"
                    echo "$package"
                    ;;
            esac
            ;;
        arch)
            case "$package" in
                postfix) echo "postfix" ;;
                postfix-mysql) echo "postfix-mysql" ;;
                postfix-policyd-spf) echo "postfix-policyd-spf-perl" ;;
                dovecot) echo "dovecot" ;;
                dovecot-mysql) echo "" ;; # Included in dovecot
                mysql-server) echo "mariadb" ;;
                mysql-client) echo "mariadb-clients" ;;
                spamassassin) echo "spamassassin" ;;
                clamav) echo "clamav" ;;
                certbot) echo "certbot certbot-apache" ;;
                opendkim) echo "opendkim" ;;
                rspamd) echo "rspamd" ;;
                postfixadmin) echo "postfixadmin" ;;
                roundcube) echo "roundcubemail" ;;
                sogo) echo "sogo" ;;
                php) echo "php php-fpm php-imap php-json" ;;
                nginx) echo "nginx" ;;
                apache) echo "apache" ;;
                wget) echo "wget" ;;
                unzip) echo "unzip" ;;
                *)
                    log_warning "Unknown package: $package"
                    echo "$package"
                    ;;
            esac
            ;;
        suse)
            case "$package" in
                postfix) echo "postfix" ;;
                postfix-mysql) echo "postfix-mysql" ;;
                dovecot) echo "dovecot" ;;
                mysql-server) echo "mariadb" ;;
                spamassassin) echo "spamassassin" ;;
                certbot) echo "certbot" ;;
                roundcube) echo "roundcubemail" ;;
                sogo) echo "sogo" ;;
                php) echo "php7 php7-fpm php7-mysql php7-imap php7-mbstring" ;;
                nginx) echo "nginx" ;;
                apache) echo "apache2" ;;
                wget) echo "wget" ;;
                unzip) echo "unzip" ;;
                *)
                    echo "$package"
                    ;;
            esac
            ;;
    esac
}

# ============================================================================
# PACKAGE MANAGEMENT
# ============================================================================

update_package_cache() {
    log_step "Updating package cache..."
    
    case "$PACKAGE_MANAGER" in
        apt-get)
            apt-get update -qq
            ;;
        yum|dnf)
            $PACKAGE_MANAGER makecache -q
            ;;
        pacman)
            pacman -Sy --noconfirm
            ;;
        zypper)
            zypper refresh
            ;;
    esac
    
    log_success "Package cache updated"
}

install_package() {
    local package_name="$1"
    local actual_packages
    actual_packages=$(get_package_name "$package_name")
    
    if [[ -z "$actual_packages" ]]; then
        log_info "Skipping $package_name (not needed for this distribution)"
        return 0
    fi
    
    log_step "Installing: $package_name ($actual_packages)"
    
    case "$PACKAGE_MANAGER" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $actual_packages
            ;;
        yum|dnf)
            $PACKAGE_MANAGER install -y -q $actual_packages
            ;;
        pacman)
            pacman -S --noconfirm --needed $actual_packages
            ;;
        zypper)
            zypper install -y $actual_packages
            ;;
    esac
    
    log_success "Installed: $package_name"
}

# ============================================================================
# PACKAGE AVAILABILITY CHECKING
# ============================================================================

check_package_available() {
    local package="$1"
    local pkg_name=$(get_package_name "$package")
    
    # Empty package name means not available
    if [ -z "$pkg_name" ]; then
        return 1
    fi
    
    # Check if package exists in repositories
    case "$PACKAGE_MANAGER" in
        apt-get)
            apt-cache show "$pkg_name" &>/dev/null
            return $?
            ;;
        yum|dnf)
            $PACKAGE_MANAGER info "$pkg_name" &>/dev/null 2>&1
            return $?
            ;;
        pacman)
            pacman -Si "$pkg_name" &>/dev/null 2>&1
            return $?
            ;;
        zypper)
            zypper info "$pkg_name" &>/dev/null 2>&1
            return $?
            ;;
        *)
            # Unknown package manager, assume available
            return 0
            ;;
    esac
}

# ============================================================================
# WEB SERVER DETECTION AND SELECTION
# ============================================================================

detect_or_choose_webserver() {
    log_step "Detecting web server..."
    
    # Check if nginx is already installed and running
    if systemctl is-active --quiet nginx 2>/dev/null || command -v nginx &>/dev/null; then
        WEB_SERVER="nginx"
        log_success "Detected existing Nginx installation"
        return 0
    fi
    
    # Check if apache is already installed and running
    if systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null || command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
        WEB_SERVER="apache"
        log_success "Detected existing Apache installation"
        return 0
    fi
    
    # No web server found, ask user preference
    log_info "No web server detected"
    echo ""
    echo -e "${CYAN}Choose a web server for webmail:${NC}"
    echo -e "${CYAN}1)${NC} Nginx (recommended - lightweight, fast)"
    echo -e "${CYAN}2)${NC} Apache (traditional, well-known)"
    echo ""
    
    local choice
    while true; do
        choice=$(ask_question "Select web server [1-2]:" "1")
        case "$choice" in
            1)
                WEB_SERVER="nginx"
                log_success "Selected: Nginx"
                break
                ;;
            2)
                WEB_SERVER="apache"
                log_success "Selected: Apache"
                break
                ;;
            *)
                log_error "Invalid selection. Please choose 1 or 2"
                ;;
        esac
    done
}

# ============================================================================
# USER INPUT COLLECTION
# ============================================================================

collect_basic_info() {
    print_section "Basic Configuration"
    
    echo -e "${WHITE}Let's configure your mail server. I'll ask you a few questions.${NC}\n"
    
    # Primary domain
    while true; do
        PRIMARY_DOMAIN=$(ask_question "Enter your primary mail domain (e.g., example.com):")
        if [[ "$PRIMARY_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z]{2,}$ ]]; then
            DOMAINS+=("$PRIMARY_DOMAIN")
            break
        else
            log_error "Invalid domain format. Please try again."
        fi
    done
    
    # Hostname
    HOSTNAME=$(ask_question "Enter the mail server hostname:" "mail.$PRIMARY_DOMAIN")
    
    # Admin email
    ADMIN_EMAIL=$(ask_question "Enter admin email address:" "admin@$PRIMARY_DOMAIN")
    
    # Additional domains
    echo ""
    if ask_yes_no "Do you want to add additional domains?" "n"; then
        while true; do
            local domain
            domain=$(ask_question "Enter additional domain (or press Enter to finish):")
            if [[ -z "$domain" ]]; then
                break
            elif [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z]{2,}$ ]]; then
                DOMAINS+=("$domain")
                log_success "Added domain: $domain"
            else
                log_error "Invalid domain format"
            fi
        done
    fi
    
    echo ""
    log_info "Configuration summary:"
    log_info "  Primary domain: $PRIMARY_DOMAIN"
    log_info "  Hostname: $HOSTNAME"
    log_info "  Admin email: $ADMIN_EMAIL"
    log_info "  Total domains: ${#DOMAINS[@]}"
    for domain in "${DOMAINS[@]}"; do
        log_info "    - $domain"
    done
    
    pause_for_user
}

collect_component_choices() {
    print_section "Component Selection"
    
    echo -e "${WHITE}Select which components to install:${NC}\n"
    
    # Mandatory components
    echo -e "${GREEN}✓ Postfix (SMTP Server) - MANDATORY${NC}"
    echo -e "${GREEN}✓ Dovecot (IMAP/POP3 Server) - MANDATORY${NC}"
    echo -e "${GREEN}✓ MariaDB (Database) - MANDATORY${NC}"
    echo -e "${GREEN}✓ Certbot (SSL Certificates) - MANDATORY${NC}"
    
    echo ""
    echo -e "${YELLOW}Security & Anti-Spam Components:${NC}"
    
    # Policyd-SPF (mandatory)
    echo -e "${GREEN}✓ Policyd-SPF (SPF Checking) - MANDATORY${NC}"
    ENABLE_POLICYD_SPF=true
    
    # SpamAssassin
    if ask_yes_no "Install SpamAssassin? (spam filtering)" "y"; then
        ENABLE_SPAMASSASSIN=true
    fi
    
    # ClamAV
    if ask_yes_no "Install ClamAV? (antivirus scanning)" "n"; then
        ENABLE_CLAMAV=true
    fi
    
    # Rspamd (alternative to SpamAssassin)
    if ! $ENABLE_SPAMASSASSIN; then
        if ask_yes_no "Install Rspamd? (modern spam filtering alternative)" "n"; then
            ENABLE_RSPAMD=true
        fi
    fi
    
    # OpenDKIM
    echo ""
    if ask_yes_no "Install OpenDKIM? (email authentication)" "y"; then
        ENABLE_DKIM=true
    fi
    
    echo ""
    echo -e "${YELLOW}Web-based Management Tools:${NC}"
    
    # PostfixAdmin (mandatory)
    echo -e "${GREEN}✓ PostfixAdmin (Web management interface) - MANDATORY${NC}"
    ENABLE_POSTFIXADMIN=true
    
    # Webmail client selection
    echo ""
    echo -e "${YELLOW}Webmail Client (browser-based email access):${NC}"
    echo ""
    
    # Build list of available webmail options
    local -a available_options=()
    local -a option_names=()
    local option_num=1
    
    # SnappyMail is always available (downloaded from GitHub)
    available_options+=("snappymail")
    option_names+=("$option_num")
    echo -e "${CYAN}$option_num)${NC} ${BOLD}SnappyMail${NC} ${GREEN}(Recommended)${NC}"
    echo -e "   Modern, fast webmail with no database requirement"
    echo -e "   Lightweight and easy to maintain"
    echo ""
    ((option_num++))
    
    # Roundcube - check if available in repos
    if check_package_available "roundcube"; then
        available_options+=("roundcube")
        option_names+=("$option_num")
        echo -e "${CYAN}$option_num)${NC} ${BOLD}Roundcube${NC}"
        echo -e "   Feature-rich and mature webmail"
        echo -e "   Extensive plugin ecosystem, Outlook-like interface"
        echo ""
        ((option_num++))
    fi
    
    # SOGo - check if available in repos
    if check_package_available "sogo"; then
        available_options+=("sogo")
        option_names+=("$option_num")
        echo -e "${CYAN}$option_num)${NC} ${BOLD}SOGo${NC}"
        echo -e "   Full groupware solution (email + calendar + contacts)"
        echo -e "   ActiveSync support, ideal for organizations"
        echo ""
        ((option_num++))
    fi
    
    # None option
    local none_option=$option_num
    available_options+=("none")
    option_names+=("$option_num")
    echo -e "${CYAN}$option_num)${NC} ${BOLD}None${NC}"
    echo -e "   Skip webmail installation"
    echo ""
    
    local webmail_selection
    while true; do
        webmail_selection=$(ask_question "Select webmail client [1-$option_num]:" "1")
        if [[ "$webmail_selection" -ge 1 && "$webmail_selection" -le "$option_num" ]]; then
            WEBMAIL_CHOICE="${available_options[$((webmail_selection-1))]}"
            if [ "$WEBMAIL_CHOICE" = "none" ]; then
                log_info "Skipping webmail installation"
            else
                log_success "Selected: ${WEBMAIL_CHOICE^}"
                # Detect or choose web server if webmail is being installed
                detect_or_choose_webserver
            fi
            break
        else
            log_error "Invalid selection. Please choose 1-$option_num"
        fi
    done
    
    echo ""
    log_info "Selected components:"
    log_info "  ✓ Core: Postfix, Dovecot, MariaDB, Certbot"
    log_info "  ✓ Policyd-SPF: YES"
    log_info "  SpamAssassin: $([ $ENABLE_SPAMASSASSIN == true ] && echo YES || echo NO)"
    log_info "  ClamAV: $([ $ENABLE_CLAMAV == true ] && echo YES || echo NO)"
    log_info "  Rspamd: $([ $ENABLE_RSPAMD == true ] && echo YES || echo NO)"
    log_info "  OpenDKIM: $([ $ENABLE_DKIM == true ] && echo YES || echo NO)"
    log_info "  ✓ PostfixAdmin: YES"
    log_info "  Webmail: $([ $WEBMAIL_CHOICE == none ] && echo NONE || echo ${WEBMAIL_CHOICE^^})"
    
    pause_for_user
}

generate_passwords() {
    print_section "Password Generation"
    
    log_info "Generating secure passwords..."
    
    # Generate database password
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    log_success "Database password generated"
    
    # Generate PostfixAdmin setup password
    POSTFIXADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    log_success "PostfixAdmin password generated"
    
    # Generate webmail password if needed
    if [[ "$WEBMAIL_CHOICE" != "none" && "$WEBMAIL_CHOICE" != "snappymail" ]]; then
        WEBMAIL_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        log_success "Webmail database password generated"
    fi
    
    echo ""
    log_warning "IMPORTANT: Save these passwords securely!"
    echo ""
    echo -e "${BOLD}Database Password:${NC} ${WHITE}$DB_PASSWORD${NC}"
    echo -e "${BOLD}PostfixAdmin Setup Password:${NC} ${WHITE}$POSTFIXADMIN_PASSWORD${NC}"
    if [[ "$WEBMAIL_CHOICE" != "none" && "$WEBMAIL_CHOICE" != "snappymail" ]]; then
        echo -e "${BOLD}Webmail Database Password:${NC} ${WHITE}$WEBMAIL_PASSWORD${NC}"
    fi
    echo ""
    
    pause_for_user
}

# ============================================================================
# DNS TESTING AND CONFIGURATION
# ============================================================================

get_server_ip() {
    # Try to detect server's public IP address
    local ip=""
    
    # Try multiple methods to get public IP
    ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    
    if [[ -z "$ip" ]]; then
        # Fallback to local IP if public IP detection fails
        ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
    fi
    
    echo "$ip"
}

test_dns_records() {
    print_section "Testing DNS Configuration"
    
    log_info "Detecting server IP address..."
    local server_ip
    server_ip=$(get_server_ip)
    
    if [[ -z "$server_ip" ]]; then
        log_error "Could not detect server IP address"
        SERVER_IP="YOUR_SERVER_IP"
    else
        log_success "Server IP detected: $server_ip"
        SERVER_IP="$server_ip"
    fi
    
    echo ""
    log_info "Testing DNS records for configured domains..."
    echo ""
    
    local dns_issues=()
    local dns_ok=()
    
    # Check hostname A record
    log_step "Testing hostname: $HOSTNAME"
    local hostname_ip
    hostname_ip=$(dig +short "$HOSTNAME" A 2>/dev/null | head -1)
    
    if [[ -z "$hostname_ip" ]]; then
        log_warning "✗ A record not found for $HOSTNAME"
        dns_issues+=("hostname_a")
    elif [[ "$hostname_ip" == "$SERVER_IP" ]]; then
        log_success "✓ A record correctly points to $SERVER_IP"
        dns_ok+=("hostname_a")
    else
        log_warning "✗ A record points to $hostname_ip (expected $SERVER_IP)"
        dns_issues+=("hostname_a_wrong")
    fi
    
    # Check each domain
    for domain in "${DOMAINS[@]}"; do
        echo ""
        log_step "Testing domain: $domain"
        
        # Check MX record
        local mx_record
        mx_record=$(dig +short "$domain" MX 2>/dev/null | head -1)
        
        if [[ -z "$mx_record" ]]; then
            log_warning "✗ MX record not found"
            dns_issues+=("${domain}_mx")
        else
            log_success "✓ MX record exists: $mx_record"
            dns_ok+=("${domain}_mx")
        fi
        
        # Check SPF record
        local spf_record
        spf_record=$(dig +short "$domain" TXT 2>/dev/null | grep -i "v=spf1")
        
        if [[ -z "$spf_record" ]]; then
            log_warning "✗ SPF record not found"
            dns_issues+=("${domain}_spf")
        else
            log_success "✓ SPF record exists"
            dns_ok+=("${domain}_spf")
        fi
        
        # Check DMARC record
        local dmarc_record
        dmarc_record=$(dig +short "_dmarc.$domain" TXT 2>/dev/null | grep -i "v=DMARC1")
        
        if [[ -z "$dmarc_record" ]]; then
            log_warning "✗ DMARC record not found"
            dns_issues+=("${domain}_dmarc")
        else
            log_success "✓ DMARC record exists"
            dns_ok+=("${domain}_dmarc")
        fi
    done
    
    echo ""
    if [[ ${#dns_issues[@]} -eq 0 ]]; then
        log_success "All DNS records are properly configured!"
    else
        log_warning "Some DNS records need to be configured (${#dns_issues[@]} issues found)"
    fi
    
    pause_for_user
}

show_dns_configuration() {
    print_section "DNS Configuration Guide"
    
    cat << EOF
${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           DNS Records Configuration for Domain Provider          ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝${NC}

${WHITE}Please configure the following DNS records with your domain provider.
These records are essential for your mail server to work properly.${NC}

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BOLD}${GREEN}1. A RECORD (Required - Points your hostname to this server)${NC}
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${CYAN}Record Type:${NC}  A
${CYAN}Hostname:${NC}     $HOSTNAME
${CYAN}Points to:${NC}    $SERVER_IP
${CYAN}TTL:${NC}          3600 (or your provider's default)

${WHITE}Example for DNS provider interface:${NC}
┌─────────────────────────────────────────────────────────┐
│ Type │ Name/Host          │ Value/Points to  │ TTL  │
├──────┼────────────────────┼──────────────────┼──────┤
│  A   │ mail (or $HOSTNAME)│ $SERVER_IP       │ 3600 │
└─────────────────────────────────────────────────────────┘

EOF

    # Show MX and other records for each domain
    for domain in "${DOMAINS[@]}"; do
        cat << EOF

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BOLD}${GREEN}DNS RECORDS FOR: $domain${NC}
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BOLD}${GREEN}2. MX RECORD (Required - Tells other servers where to send email)${NC}

${CYAN}Record Type:${NC}  MX
${CYAN}Hostname:${NC}     @ (or $domain)
${CYAN}Points to:${NC}    $HOSTNAME
${CYAN}Priority:${NC}     10
${CYAN}TTL:${NC}          3600

${WHITE}Example:${NC}
┌─────────────────────────────────────────────────────────┐
│ Type │ Name/Host   │ Mail Server      │ Priority │ TTL  │
├──────┼─────────────┼──────────────────┼──────────┼──────┤
│  MX  │ @ or blank  │ $HOSTNAME        │    10    │ 3600 │
└─────────────────────────────────────────────────────────┘

${BOLD}${GREEN}3. SPF RECORD (Required - Prevents email spoofing)${NC}

${CYAN}Record Type:${NC}  TXT
${CYAN}Hostname:${NC}     @ (or $domain)
${CYAN}Value:${NC}        "v=spf1 mx a:$HOSTNAME -all"
${CYAN}TTL:${NC}          3600

${WHITE}Explanation:${NC}
  v=spf1          : SPF version 1
  mx              : Allow servers listed in MX records
  a:$HOSTNAME : Allow the mail server
  -all            : Reject all other servers (strict)

${WHITE}Example:${NC}
┌─────────────────────────────────────────────────────────────────┐
│ Type │ Name/Host  │ Value                                  │ TTL  │
├──────┼────────────┼────────────────────────────────────────┼──────┤
│ TXT  │ @ or blank │ "v=spf1 mx a:$HOSTNAME -all"           │ 3600 │
└─────────────────────────────────────────────────────────────────┘

${WHITE}Alternative (less strict):${NC} "v=spf1 mx a:$HOSTNAME ~all"
  ~all = softfail (mark as suspicious but don't reject)

${BOLD}${GREEN}4. DMARC RECORD (Recommended - Email authentication policy)${NC}

${CYAN}Record Type:${NC}  TXT
${CYAN}Hostname:${NC}     _dmarc (or _dmarc.$domain)
${CYAN}Value:${NC}        "v=DMARC1; p=quarantine; rua=mailto:$ADMIN_EMAIL; pct=100"
${CYAN}TTL:${NC}          3600

${WHITE}Explanation:${NC}
  v=DMARC1             : DMARC version 1
  p=quarantine         : Quarantine suspicious emails
  rua=mailto:$ADMIN_EMAIL : Send reports to this address
  pct=100              : Apply policy to 100% of emails

${WHITE}Example:${NC}
┌──────────────────────────────────────────────────────────────────────────┐
│ Type │ Name/Host │ Value                                                │ TTL  │
├──────┼───────────┼──────────────────────────────────────────────────────┼──────┤
│ TXT  │ _dmarc    │ "v=DMARC1; p=quarantine; rua=mailto:$ADMIN_EMAIL..." │ 3600 │
└──────────────────────────────────────────────────────────────────────────┘

${WHITE}DMARC Policy Options:${NC}
  p=none       : Monitor only (recommended for testing)
  p=quarantine : Mark suspicious emails as spam
  p=reject     : Reject suspicious emails (strictest)

EOF

        if $ENABLE_DKIM; then
            cat << EOF
${BOLD}${GREEN}5. DKIM RECORD (Will be generated after installation)${NC}

${CYAN}Record Type:${NC}  TXT
${CYAN}Hostname:${NC}     default._domainkey (or default._domainkey.$domain)
${CYAN}Value:${NC}        (Generated after OpenDKIM setup)
${CYAN}TTL:${NC}          3600

${YELLOW}NOTE:${NC} The DKIM public key will be generated during OpenDKIM configuration.
      Run this command after installation to get your DKIM record:
      
      ${WHITE}sudo cat /etc/opendkim/keys/$domain/default.txt${NC}
      
      Then add it as a TXT record in your DNS.

EOF
        fi
    done
    
    cat << EOF

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BOLD}${WHITE}IMPORTANT NOTES${NC}
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${WHITE}1. DNS Propagation Time${NC}
   DNS changes can take up to 48 hours to propagate worldwide.
   Usually, changes are visible within minutes to a few hours.
   
   ${CYAN}Test propagation:${NC}
   dig $HOSTNAME
   dig $PRIMARY_DOMAIN MX
   dig $PRIMARY_DOMAIN TXT

${WHITE}2. Order of Operations${NC}
   ${GREEN}✓${NC} Configure A record FIRST (for hostname)
   ${GREEN}✓${NC} Wait 5-10 minutes for propagation
   ${GREEN}✓${NC} Then configure MX, SPF, and DMARC records
   ${GREEN}✓${NC} SSL certificate generation requires A record to work

${WHITE}3. Testing Your DNS${NC}
   Online tools to verify your configuration:
   • MXToolbox: https://mxtoolbox.com/
   • DNS Checker: https://dnschecker.org/
   • Mail Tester: https://www.mail-tester.com/

${WHITE}4. Common Mistakes${NC}
   ${RED}✗${NC} Forgetting the dot at the end: mail.example.com${RED}.${NC}
   ${RED}✗${NC} Using IP address in MX record (should be hostname)
   ${RED}✗${NC} Missing quotes around TXT record values
   ${RED}✗${NC} Wrong priority for MX (use 10 or lower)

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF

    log_info "DNS configuration guide displayed"
    echo ""
    log_warning "Please configure these DNS records before proceeding with SSL certificates"
    echo ""
    
    pause_for_user
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

install_core_packages() {
    print_section "Installing Core Packages"
    
    log_step "Installing Postfix..."
    install_package "postfix"
    install_package "postfix-mysql"
    
    log_step "Installing Dovecot..."
    install_package "dovecot"
    install_package "dovecot-mysql"
    
    log_step "Installing MariaDB..."
    install_package "mysql-server"
    install_package "mysql-client"
    
    log_step "Installing Certbot..."
    install_package "certbot"
    
    log_success "Core packages installed"
}

install_optional_packages() {
    print_section "Installing Optional Packages"
    
    if $ENABLE_POLICYD_SPF; then
        install_package "postfix-policyd-spf"
    fi
    
    if $ENABLE_SPAMASSASSIN; then
        install_package "spamassassin"
    fi
    
    if $ENABLE_CLAMAV; then
        install_package "clamav"
    fi
    
    if $ENABLE_DKIM; then
        install_package "opendkim"
    fi
    
    if $ENABLE_RSPAMD; then
        install_package "rspamd"
    fi
    
    if $ENABLE_POSTFIXADMIN; then
        install_package "php"
        install_package "nginx"
    fi
    
    if $ENABLE_ROUNDCUBE; then
        install_package "roundcube"
    fi
    
    log_success "Optional packages installed"
}

# ============================================================================
# DATABASE SETUP
# ============================================================================

setup_database() {
    print_section "Configuring Database"
    
    log_step "Starting MariaDB..."
    systemctl start mariadb || systemctl start mysql || true
    systemctl enable mariadb || systemctl enable mysql || true
    
    log_step "Creating mail database and user..."
    
    mysql -u root <<EOF
-- Create database
CREATE DATABASE IF NOT EXISTS mail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user
CREATE USER IF NOT EXISTS 'mailuser'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT SELECT ON mail.* TO 'mailuser'@'localhost';
FLUSH PRIVILEGES;

-- Use database
USE mail;

-- ============================================================================
-- DOMAINS TABLE
-- Stores all virtual mail domains that this server handles
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_domains (
    id INT AUTO_INCREMENT PRIMARY KEY,
    domain VARCHAR(255) NOT NULL UNIQUE COMMENT 'Domain name (e.g., example.com)',
    description TEXT COMMENT 'Optional description of the domain',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_domain (domain),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Virtual mail domains';

-- ============================================================================
-- USERS TABLE
-- Stores all email user accounts with encrypted passwords
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE COMMENT 'Full email address (user@domain.com)',
    domain_id INT NOT NULL COMMENT 'Reference to mail_domains table',
    password VARCHAR(255) NOT NULL COMMENT 'Encrypted password (use SHA512-CRYPT or BCRYPT)',
    name VARCHAR(255) DEFAULT NULL COMMENT 'Full name of the user',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    quota_bytes BIGINT DEFAULT 5368709120 COMMENT 'Storage quota in bytes (default 5GB)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES mail_domains(id) ON DELETE CASCADE,
    INDEX idx_email (email),
    INDEX idx_domain_id (domain_id),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Email user accounts';

-- ============================================================================
-- ALIASES TABLE
-- Email aliases that forward to other addresses
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_aliases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    source_email VARCHAR(255) NOT NULL COMMENT 'Source alias address (info@example.com)',
    destination_email VARCHAR(255) NOT NULL COMMENT 'Destination email (user@example.com)',
    domain_id INT NOT NULL COMMENT 'Reference to mail_domains table',
    enabled TINYINT(1) DEFAULT 1 COMMENT '1 = active, 0 = disabled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES mail_domains(id) ON DELETE CASCADE,
    INDEX idx_source (source_email),
    INDEX idx_destination (destination_email),
    INDEX idx_enabled (enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Email aliases and forwards';

-- ============================================================================
-- AUDIT LOG TABLE
-- Tracks important events for security and compliance
-- ============================================================================
CREATE TABLE IF NOT EXISTS mail_audit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT DEFAULT NULL COMMENT 'Reference to mail_users table',
    action VARCHAR(50) NOT NULL COMMENT 'Action performed (login, password_change, etc)',
    details TEXT COMMENT 'Additional details about the action',
    ip_address VARCHAR(45) COMMENT 'IP address of the client',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES mail_users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit log for security and compliance';

-- Insert configured domains
EOF

    # Insert domains
    for domain in "${DOMAINS[@]}"; do
        mysql -u root mail <<EOF
INSERT IGNORE INTO mail_domains (domain, description) 
VALUES ('$domain', 'Configured by installation script');
EOF
        log_success "Added domain to database: $domain"
    done
    
    log_success "Database configured successfully"
}

# ============================================================================
# POSTFIX CONFIGURATION
# ============================================================================

configure_postfix() {
    print_section "Configuring Postfix"
    
    log_step "Backing up original configuration..."
    [[ -f "$POSTFIX_DIR/main.cf" ]] && cp "$POSTFIX_DIR/main.cf" "$POSTFIX_DIR/main.cf.backup.$(date +%Y%m%d)"
    [[ -f "$POSTFIX_DIR/master.cf" ]] && cp "$POSTFIX_DIR/master.cf" "$POSTFIX_DIR/master.cf.backup.$(date +%Y%m%d)"
    
    log_step "Generating main.cf..."
    
    cat > "$POSTFIX_DIR/main.cf" << 'MAINCONF'
# ============================================================================
# POSTFIX MAIN CONFIGURATION
# Generated by interactive mail server installation script
# ============================================================================

# ----------------------------------------------------------------------------
# BASIC SETTINGS
# These define the server's identity and basic behavior
# ----------------------------------------------------------------------------

# The fully qualified domain name of this mail server
# This is what other mail servers see when connecting to you
myhostname = HOSTNAME_PLACEHOLDER

# The domain that appears in the "From" address for locally-posted mail
# Usually set to your primary domain
myorigin = PRIMARY_DOMAIN_PLACEHOLDER

# The domain name that this server considers "local"
# Typically this is just the server hostname and localhost
mydomain = PRIMARY_DOMAIN_PLACEHOLDER

# List of domains that are delivered locally (not forwarded)
# For virtual domains, we leave this minimal
mydestination = $myhostname, localhost.$mydomain, localhost

# Networks that are allowed to relay mail through this server
# Be very careful with this - only trusted networks should be here
mynetworks = 127.0.0.0/8, [::1]/128

# Which network interfaces to listen on
# "all" means listen on all available network interfaces
inet_interfaces = all

# IP protocol versions to use (ipv4, ipv6, or both)
inet_protocols = all

# ----------------------------------------------------------------------------
# VIRTUAL DOMAIN CONFIGURATION
# These settings enable support for multiple mail domains
# ----------------------------------------------------------------------------

# Tell Postfix which domains are virtual (stored in database)
# This MySQL query checks if a domain exists in mail_domains table
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-domains.cf

# Map email addresses to mailbox locations
# Returns the mailbox path for each email address
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf

# Map email aliases to their destination addresses
# Allows info@example.com to forward to admin@example.com
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf

# The transport method for virtual domains
# "dovecot" means deliver to Dovecot's LMTP service
virtual_transport = lmtp:unix:private/dovecot-lmtp

# Base directory where all virtual mailboxes are stored
virtual_mailbox_base = /var/vmail

# UID (user ID) for all virtual mailbox files
# Using a dedicated user (5000) for security
virtual_uid_maps = static:5000

# GID (group ID) for all virtual mailbox files
virtual_gid_maps = static:5000

# ----------------------------------------------------------------------------
# MESSAGE SIZE LIMITS
# Control how large messages can be
# ----------------------------------------------------------------------------

# Maximum size of any single email message (25MB here)
# Adjust based on your needs (value in bytes)
message_size_limit = 26214400

# Maximum size of a user's entire mailbox (0 = unlimited)
# Quota is better enforced at the Dovecot level
mailbox_size_limit = 0

# ----------------------------------------------------------------------------
# TLS/SSL CONFIGURATION (OUTGOING MAIL)
# These settings control encryption when SENDING mail
# ----------------------------------------------------------------------------

# Enable TLS for outgoing mail connections
smtp_use_tls = yes

# Use TLS if available, but don't require it
# Options: none, may, encrypt, dane, dane-only, fingerprint, verify, secure
smtp_tls_security_level = may

# Certificate Authority bundle for verifying remote certificates
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

# Cache TLS session data to improve performance
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

# Disable old, insecure SSL/TLS versions
# Only allow TLSv1.2 and TLSv1.3
smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Use high-security cipher suites only
smtp_tls_ciphers = high

# Minimum Diffie-Hellman key size
smtp_tls_dh_min_bits = 2048

# Log TLS connection details for debugging
smtp_tls_loglevel = 1

# ----------------------------------------------------------------------------
# TLS/SSL CONFIGURATION (INCOMING MAIL)
# These settings control encryption when RECEIVING mail
# ----------------------------------------------------------------------------

# Enable TLS for incoming mail connections
smtpd_use_tls = yes

# Accept both encrypted and unencrypted connections
# The submission port (587) will require encryption
smtpd_tls_security_level = may

# Path to your SSL certificate file
# This will be populated by Certbot
smtpd_tls_cert_file = /etc/letsencrypt/live/HOSTNAME_PLACEHOLDER/fullchain.pem

# Path to your SSL private key file
smtpd_tls_key_file = /etc/letsencrypt/live/HOSTNAME_PLACEHOLDER/privkey.pem

# Cache TLS session data
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache

# Disable old, insecure SSL/TLS versions
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Use high-security cipher suites (Mozilla Modern compatibility)
# Only allow TLS 1.2+ with strong ciphers - no weak/deprecated ciphers
smtpd_tls_ciphers = high
smtpd_tls_mandatory_ciphers = high
smtpd_tls_exclude_ciphers = 
    aNULL, eNULL, EXPORT, DES, 3DES, MD5, PSK, RC4, 
    DSS, SEED, IDEA, CAMELLIA, CBC

# Prefer server cipher order (more secure)
smtpd_tls_prefer_server_ciphers = yes

# Minimum Diffie-Hellman key size (2048 minimum, 4096 recommended)
smtpd_tls_dh_min_bits = 2048

# Log TLS connection details
smtpd_tls_loglevel = 1

# ----------------------------------------------------------------------------
# SASL AUTHENTICATION
# Allows users to send mail after proving their identity
# ----------------------------------------------------------------------------

# Use Dovecot for SASL authentication
smtpd_sasl_type = dovecot

# Path to Dovecot's authentication socket
smtpd_sasl_path = private/auth

# Enable SASL authentication
smtpd_sasl_auth_enable = yes

# Don't allow anonymous authentication
smtpd_sasl_security_options = noanonymous

# Support for broken email clients (Outlook, etc)
broken_sasl_auth_clients = yes

# The domain to append to unqualified usernames
smtpd_sasl_local_domain = $myhostname

# ----------------------------------------------------------------------------
# RELAY RESTRICTIONS
# Control who can send mail through this server
# ----------------------------------------------------------------------------

# Main relay policy
# These rules determine who can send mail through your server
smtpd_relay_restrictions = 
    permit_mynetworks,            # Allow mail from trusted networks
    permit_sasl_authenticated,    # Allow authenticated users
    defer_unauth_destination      # Temporarily reject others

# ----------------------------------------------------------------------------
# RECIPIENT RESTRICTIONS
# Control which recipients will accept mail for
# ----------------------------------------------------------------------------

smtpd_recipient_restrictions =
    permit_mynetworks,                    # Allow from trusted networks
    permit_sasl_authenticated,            # Allow authenticated users
    reject_unauth_destination,            # Reject if not our domain
    reject_invalid_hostname,              # Reject malformed hostnames
    reject_non_fqdn_hostname,             # Reject non-FQDN hostnames
    reject_non_fqdn_sender,               # Reject non-FQDN senders
    reject_non_fqdn_recipient,            # Reject non-FQDN recipients
    reject_unknown_sender_domain,         # Reject unknown sender domains
    reject_unknown_recipient_domain,      # Reject unknown recipient domains
    reject_rbl_client zen.spamhaus.org,   # Check Spamhaus blocklist
    reject_rbl_client bl.spamcop.net,     # Check SpamCop blocklist
    permit                                # Accept if passed all checks

# ----------------------------------------------------------------------------
# SENDER RESTRICTIONS
# Validate the sender's address
# ----------------------------------------------------------------------------

smtpd_sender_restrictions =
    permit_mynetworks,              # Allow from trusted networks
    permit_sasl_authenticated,      # Allow authenticated users
    reject_non_fqdn_sender,         # Reject non-FQDN sender addresses
    reject_unknown_sender_domain    # Reject unknown sender domains

# ----------------------------------------------------------------------------
# HELO/EHLO RESTRICTIONS
# Validate the HELO/EHLO hostname provided by connecting servers
# ----------------------------------------------------------------------------

smtpd_helo_restrictions =
    permit_mynetworks,                # Allow from trusted networks
    permit_sasl_authenticated,        # Allow authenticated users
    reject_invalid_helo_hostname,     # Reject malformed HELO names
    reject_non_fqdn_helo_hostname,    # Reject non-FQDN HELO names
    reject_unknown_helo_hostname      # Reject unknown HELO names

# Require HELO/EHLO at the start of SMTP sessions
smtpd_helo_required = yes

# ----------------------------------------------------------------------------
# LOGGING
# Control what information is logged
# ----------------------------------------------------------------------------

# Where to write mail logs
# On systemd systems, this goes to journald
maillog_file = /var/log/mail.log

# Log level for debugging (0=off, 1=normal, 2=verbose)
# Set to 2 temporarily if you need to troubleshoot issues
debug_peer_level = 2

# ----------------------------------------------------------------------------
# PERFORMANCE TUNING
# Adjust these based on your server's capacity
# ----------------------------------------------------------------------------

# Maximum number of parallel deliveries to the same destination
default_destination_concurrency_limit = 20

# Maximum number of parallel local deliveries
local_destination_concurrency_limit = 2

# Maximum number of Postfix processes
default_process_limit = 100

# ----------------------------------------------------------------------------
# MAIL QUEUE SETTINGS
# Control how mail is queued and retried
# ----------------------------------------------------------------------------

# How long to keep trying to deliver a message (5 days)
maximal_queue_lifetime = 5d

# How long to keep bounce messages (5 days)
bounce_queue_lifetime = 5d

# Minimum time between delivery attempts (5 minutes)
minimal_backoff_time = 300s

# Maximum time between delivery attempts (1 hour)
maximal_backoff_time = 3600s

# ----------------------------------------------------------------------------
# MISC SECURITY SETTINGS
# ----------------------------------------------------------------------------

# Disable VRFY command (prevents email address harvesting)
disable_vrfy_command = yes

# Strict RFC compliance for mail address syntax
strict_rfc821_envelopes = yes

# Don't send notifications when delivery is delayed
# (many spammers use fake sender addresses)
notify_classes = resource, software

# Reject messages with unknown local recipients quickly
unknown_local_recipient_reject_code = 550

# ----------------------------------------------------------------------------
# SMTPD BANNER
# What remote servers see when they connect
# ----------------------------------------------------------------------------

# Custom banner (don't reveal version info for security)
smtpd_banner = $myhostname ESMTP

# ----------------------------------------------------------------------------
# POLICYD-SPF CONFIGURATION
# Enables SPF (Sender Policy Framework) checking
# ----------------------------------------------------------------------------

# Check SPF records for incoming mail
# This helps prevent email spoofing
POLICYD_SPF_PLACEHOLDER

# ----------------------------------------------------------------------------
# MILTER CONFIGURATION (DKIM)
# Mail filters for DKIM signing
# ----------------------------------------------------------------------------

DKIM_PLACEHOLDER

# ============================================================================
# END OF MAIN CONFIGURATION
# ============================================================================
MAINCONF

    # Replace placeholders
    sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" "$POSTFIX_DIR/main.cf"
    sed -i "s/PRIMARY_DOMAIN_PLACEHOLDER/$PRIMARY_DOMAIN/g" "$POSTFIX_DIR/main.cf"
    
    # Add Policyd-SPF if enabled
    if $ENABLE_POLICYD_SPF; then
        sed -i "s/POLICYD_SPF_PLACEHOLDER/policyd-spf_time_limit = 3600/" "$POSTFIX_DIR/main.cf"
    else
        sed -i "s/POLICYD_SPF_PLACEHOLDER//g" "$POSTFIX_DIR/main.cf"
    fi
    
    # Add DKIM configuration if enabled
    if $ENABLE_DKIM; then
        cat >> "$POSTFIX_DIR/main.cf" << 'EOF'

# DKIM signing with OpenDKIM
milter_default_action = accept
milter_protocol = 6
smtpd_milters = inet:localhost:8891
non_smtpd_milters = $smtpd_milters
EOF
        sed -i "s/DKIM_PLACEHOLDER//g" "$POSTFIX_DIR/main.cf"
    else
        sed -i "s/DKIM_PLACEHOLDER//g" "$POSTFIX_DIR/main.cf"
    fi
    
    log_success "Generated main.cf with extensive comments"
    
    # Create MySQL configuration files
    create_mysql_configs
    
    # Configure master.cf
    configure_postfix_master
    
    log_success "Postfix configuration complete"
}

create_mysql_configs() {
    log_step "Creating MySQL query configuration files..."
    
    # Virtual domains query
    cat > "$POSTFIX_DIR/mysql-virtual-domains.cf" << EOF
# ============================================================================
# MYSQL CONFIGURATION: Virtual Domains
# This file tells Postfix how to query for valid virtual domains
# ============================================================================

# Database connection settings
user = mailuser
password = $DB_PASSWORD
hosts = localhost
dbname = mail

# SQL query to check if a domain is valid
# %s is replaced with the domain being queried
# Returns 1 if the domain exists and is enabled, nothing otherwise
query = SELECT 1 FROM mail_domains WHERE domain = '%s' AND enabled = 1
EOF
    chmod 640 "$POSTFIX_DIR/mysql-virtual-domains.cf"
    
    # Virtual mailbox maps query
    cat > "$POSTFIX_DIR/mysql-virtual-mailbox-maps.cf" << EOF
# ============================================================================
# MYSQL CONFIGURATION: Virtual Mailbox Maps
# This file tells Postfix where to deliver mail for each user
# ============================================================================

# Database connection settings
user = mailuser
password = $DB_PASSWORD
hosts = localhost
dbname = mail

# SQL query to get the mailbox path for an email address
# %s is replaced with the full email address (user@domain.com)
# Returns the path where mail should be stored
# Format: domain/username (e.g., example.com/john)
query = SELECT CONCAT(SUBSTRING_INDEX(email, '@', -1), '/', SUBSTRING_INDEX(email, '@', 1), '/') FROM mail_users WHERE email = '%s' AND enabled = 1
EOF
    chmod 640 "$POSTFIX_DIR/mysql-virtual-mailbox-maps.cf"
    
    # Virtual alias maps query
    cat > "$POSTFIX_DIR/mysql-virtual-alias-maps.cf" << EOF
# ============================================================================
# MYSQL CONFIGURATION: Virtual Alias Maps
# This file tells Postfix how to handle email aliases (forwards)
# ============================================================================

# Database connection settings
user = mailuser
password = $DB_PASSWORD
hosts = localhost
dbname = mail

# SQL query to resolve email aliases
# %s is replaced with the source email address
# Returns the destination email address(es)
# Multiple destinations can be returned (one per row) for list-like behavior
query = SELECT destination_email FROM mail_aliases WHERE source_email = '%s' AND enabled = 1
EOF
    chmod 640 "$POSTFIX_DIR/mysql-virtual-alias-maps.cf"
    
    log_success "MySQL configuration files created"
}

configure_postfix_master() {
    log_step "Configuring master.cf (service definitions)..."
    
    cat > "$POSTFIX_DIR/master.cf" << 'MASTERCONF'
# ============================================================================
# POSTFIX MASTER CONFIGURATION
# This file defines all Postfix services and how they run
# Generated by interactive mail server installation script
# ============================================================================

# ----------------------------------------------------------------------------
# SMTP SERVICE (Port 25)
# Traditional SMTP - accepts mail from other mail servers
# ----------------------------------------------------------------------------
smtp      inet  n       -       y       -       -       smtpd
  # n = no privileged operation
  # - = no limit on number of processes
  # y = run in chroot jail (more secure)
  # - = no wakeup timer
  # - = no process limit
  # smtpd = the service to run

# ----------------------------------------------------------------------------
# SUBMISSION SERVICE (Port 587)
# Used by mail clients to submit outgoing mail
# Requires authentication and encryption (TLS)
# ----------------------------------------------------------------------------
submission inet n       -       y       -       -       smtpd
  # Override settings to require security
  -o syslog_name=postfix/submission        # Separate log identifier
  -o smtpd_tls_security_level=encrypt      # REQUIRE encryption (mandatory)
  -o smtpd_sasl_auth_enable=yes            # REQUIRE authentication
  -o smtpd_sasl_type=dovecot               # Use Dovecot for auth
  -o smtpd_sasl_path=private/auth          # Path to auth socket
  -o smtpd_sasl_security_options=noanonymous
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject_all
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject_all
  -o milter_macro_daemon_name=ORIGINATING  # Mark as originating mail

# ----------------------------------------------------------------------------
# SMTPS SERVICE (Port 465)
# Legacy encrypted SMTP (SMTP over SSL)
# Similar to submission but wraps connection in TLS from the start
# ----------------------------------------------------------------------------
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes             # TLS wrapper mode (immediate TLS)
  -o smtpd_tls_security_level=encrypt      # REQUIRE encryption
  -o smtpd_sasl_auth_enable=yes            # REQUIRE authentication
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject_all
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject_all
  -o milter_macro_daemon_name=ORIGINATING

# ----------------------------------------------------------------------------
# INTERNAL SERVICES
# These services handle mail processing internally
# ----------------------------------------------------------------------------

# Pickup: picks up mail from the maildrop queue
pickup    unix  n       -       y       60      1       pickup

# Cleanup: processes message headers and body
cleanup   unix  n       -       y       -       0       cleanup

# Queue manager: manages the mail queue
qmgr      unix  n       -       n       300     1       qmgr

# TLS manager: manages TLS session cache
tlsmgr    unix  -       -       y       1000?   1       tlsmgr

# Rewriter: rewrites addresses
rewrite   unix  -       -       y       -       -       trivial-rewrite

# Bounce: generates bounce messages
bounce    unix  -       -       y       -       0       bounce

# Defer: generates deferral messages
defer     unix  -       -       y       -       0       bounce

# Trace: generates delivery reports
trace     unix  -       -       y       -       0       bounce

# Verify: address verification
verify    unix  -       -       y       -       1       verify

# Flush: flushes the mail queue
flush     unix  n       -       y       1000?   0       flush

# Proxymap: provides access to Postfix lookup tables
proxymap  unix  -       -       n       -       -       proxymap

# Proxywrite: write access to maps
proxywrite unix -       -       n       -       1       proxymap

# ----------------------------------------------------------------------------
# TRANSPORT SERVICES
# These services deliver mail
# ----------------------------------------------------------------------------

# SMTP: delivers mail to remote hosts
smtp      unix  -       -       y       -       -       smtp

# Relay: relays mail through a relay host
relay     unix  -       -       y       -       -       smtp
  -o smtp_fallback_relay=

# ----------------------------------------------------------------------------
# MISCELLANEOUS SERVICES
# ----------------------------------------------------------------------------

# Show queue: displays queue contents
showq     unix  n       -       y       -       -       showq

# Error: generates error messages
error     unix  -       -       y       -       -       error

# Retry: retries failed deliveries
retry     unix  -       -       y       -       -       error

# Discard: discards messages
discard   unix  -       -       y       -       -       discard

# Local: delivers to local mailboxes (not used with virtual domains)
local     unix  -       n       n       -       -       local

# Virtual: delivers to virtual mailboxes (not used with Dovecot LMTP)
virtual   unix  -       n       n       -       -       virtual

# LMTP: Local Mail Transfer Protocol client
lmtp      unix  -       -       y       -       -       lmtp

# Anvil: connection rate limiting
anvil     unix  -       -       y       -       1       anvil

# Scache: connection cache
scache    unix  -       -       y       -       1       scache

# ----------------------------------------------------------------------------
# POLICYD-SPF SERVICE
# Checks SPF records for incoming mail
# ----------------------------------------------------------------------------
POLICYD_SPF_PLACEHOLDER

# ============================================================================
# END OF MASTER CONFIGURATION
# ============================================================================
MASTERCONF

    # Add Policyd-SPF if enabled
    if $ENABLE_POLICYD_SPF; then
        cat >> "$POSTFIX_DIR/master.cf" << 'EOF'
# SPF policy checking
# This service checks if the sending server is authorized by SPF
policyd-spf  unix  -       n       n       -       0       spawn
  user=policyd-spf argv=/usr/bin/policyd-spf
EOF
        sed -i "s/POLICYD_SPF_PLACEHOLDER//g" "$POSTFIX_DIR/master.cf"
    else
        sed -i "s/POLICYD_SPF_PLACEHOLDER//g" "$POSTFIX_DIR/master.cf"
    fi
    
    log_success "master.cf configured with extensive comments"
}

# ============================================================================
# DOVECOT CONFIGURATION
# ============================================================================

configure_dovecot() {
    print_section "Configuring Dovecot"
    
    log_step "Backing up original configuration..."
    [[ -f "$DOVECOT_DIR/dovecot.conf" ]] && cp "$DOVECOT_DIR/dovecot.conf" "$DOVECOT_DIR/dovecot.conf.backup.$(date +%Y%m%d)"
    
    log_step "Creating virtual mail user..."
    if ! id -u vmail >/dev/null 2>&1; then
        useradd -r -u $VMAIL_UID -g mail -d "$VMAIL_DIR" -s /usr/sbin/nologin -c "Virtual Mail User" vmail
    fi
    
    mkdir -p "$VMAIL_DIR"
    chown -R vmail:mail "$VMAIL_DIR"
    chmod -R 770 "$VMAIL_DIR"
    
    log_step "Generating dovecot.conf..."
    
    cat > "$DOVECOT_DIR/dovecot.conf" << 'DOVECOTCONF'
# ============================================================================
# DOVECOT MAIN CONFIGURATION
# Generated by interactive mail server installation script
# ============================================================================

# ----------------------------------------------------------------------------
# PROTOCOLS
# Which protocols to enable (IMAP, POP3, LMTP)
# ----------------------------------------------------------------------------

# Enable IMAP (recommended), POP3, and LMTP protocols
# IMAP: Modern email access protocol (supports folders, flags, etc.)
# POP3: Legacy protocol (downloads and deletes from server)
# LMTP: Local Mail Transfer Protocol (receives mail from Postfix)
protocols = imap pop3 lmtp

# ----------------------------------------------------------------------------
# NETWORK SETTINGS
# Control which addresses and ports Dovecot listens on
# ----------------------------------------------------------------------------

# Listen on all IPv4 and IPv6 addresses
listen = *, ::

# ----------------------------------------------------------------------------
# LOGGING
# Configure how Dovecot logs information
# ----------------------------------------------------------------------------

# Timestamp format for log entries
log_timestamp = "%Y-%m-%d %H:%M:%S "

# Where to send log messages (uses syslog mail facility)
syslog_facility = mail

# Log authentication successes and failures
auth_verbose = yes
auth_debug = no
auth_debug_passwords = no

# Log mail process information
mail_debug = no
verbose_ssl = no

# ----------------------------------------------------------------------------
# SSL/TLS CONFIGURATION
# Configure encryption for IMAP/POP3 connections
# ----------------------------------------------------------------------------

# SSL is required for all connections
# Options: yes (allow plain), no (disable), required (force SSL)
ssl = required

# Path to SSL certificate (will be set up by Certbot)
ssl_cert = </etc/letsencrypt/live/HOSTNAME_PLACEHOLDER/fullchain.pem

# Path to SSL private key
ssl_key = </etc/letsencrypt/live/HOSTNAME_PLACEHOLDER/privkey.pem

# Disable old, insecure SSL/TLS versions
# Only allow TLS 1.2 and 1.3
ssl_min_protocol = TLSv1.2
ssl_protocols = !SSLv2 !SSLv3 !TLSv1 !TLSv1.1

# Use strong cipher suites only - Mozilla Modern profile
# Excludes all weak/deprecated ciphers (3DES, CBC mode, RC4, etc.)
ssl_cipher_list = ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384

# Prefer server cipher order (more secure)
ssl_prefer_server_ciphers = yes

# Diffie-Hellman parameters for forward secrecy
# Generate with: openssl dhparam -out /etc/dovecot/dh.pem 4096
#ssl_dh = </etc/dovecot/dh.pem

# ----------------------------------------------------------------------------
# MAIL LOCATION
# Where and how mailboxes are stored
# ----------------------------------------------------------------------------

# Mailbox format and location
# maildir: One file per message (more reliable than mbox)
# /var/vmail/%d/%n: domain/username structure
#   %d = domain part of email (example.com)
#   %n = username part of email (john)
mail_location = maildir:/var/vmail/%d/%n/Maildir

# User and group for mail files
mail_uid = 5000
mail_gid = 5000

# Privileged group for mail access
mail_privileged_group = mail

# First and last valid UID for mail users
first_valid_uid = 5000
last_valid_uid = 5000

# First and last valid GID for mail users  
first_valid_gid = 5000
last_valid_gid = 5000

# ----------------------------------------------------------------------------
# MAILBOX CONFIGURATION
# Configure default mailbox names and special folders
# ----------------------------------------------------------------------------

# Define the namespace for user mailboxes
namespace inbox {
  # This is the inbox namespace
  inbox = yes
  
  # Folder separator character (/ or .)
  separator = /
  
  # Prefix for mailbox names (empty = no prefix)
  prefix = 
  
  # Define special-use folders (as per RFC 6154)
  # These are recognized by mail clients
  
  mailbox Drafts {
    auto = subscribe
    special_use = \Drafts
  }
  
  mailbox Sent {
    auto = subscribe
    special_use = \Sent
  }
  
  mailbox Trash {
    auto = subscribe
    special_use = \Trash
  }
  
  mailbox Spam {
    auto = subscribe
    special_use = \Junk
  }
  
  mailbox Archive {
    auto = subscribe
    special_use = \Archive
  }
}

# ----------------------------------------------------------------------------
# AUTHENTICATION
# Configure how users authenticate
# ----------------------------------------------------------------------------

# Disable plaintext authentication unless using SSL/TLS
disable_plaintext_auth = yes

# Authentication mechanisms to offer
# PLAIN: Username and password (encrypted by TLS)
# LOGIN: Legacy method for old clients
auth_mechanisms = plain login

# Include SQL authentication configuration
!include auth-sql.conf.ext

# ----------------------------------------------------------------------------
# USER DATABASE
# Where to look up user information
# ----------------------------------------------------------------------------

# Use SQL for user database
userdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}

# ----------------------------------------------------------------------------
# PASSWORD DATABASE  
# Where to verify passwords
# ----------------------------------------------------------------------------

# Use SQL for password verification
passdb {
  driver = sql
  args = /etc/dovecot/dovecot-sql.conf.ext
}

# ----------------------------------------------------------------------------
# SERVICE CONFIGURATION
# Configure Dovecot's various services
# ----------------------------------------------------------------------------

# IMAP Service
service imap-login {
  # Standard IMAP port (unencrypted, STARTTLS available)
  inet_listener imap {
    port = 143
  }
  
  # IMAPS port (TLS wrapped from the start)
  inet_listener imaps {
    port = 993
    ssl = yes
  }
  
  # Number of processes to pre-fork
  process_min_avail = 1
  
  # Maximum number of IMAP processes
  process_limit = 1024
}

# POP3 Service
service pop3-login {
  # Standard POP3 port
  inet_listener pop3 {
    port = 110
  }
  
  # POP3S port (TLS wrapped)
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
  
  process_min_avail = 1
  process_limit = 1024
}

# LMTP Service (receives mail from Postfix)
service lmtp {
  # Unix socket for Postfix to connect to
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0666
    user = postfix
    group = postfix
  }
  
  # Number of LMTP processes
  process_min_avail = 0
  process_limit = 1024
}

# Authentication Service (for Postfix SASL)
service auth {
  # Unix socket for Postfix SMTP auth
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
  
  # Unix socket for user database lookups
  unix_listener auth-userdb {
    mode = 0666
    user = vmail
    group = mail
  }
  
  # Auth process settings
  process_min_avail = 1
  process_limit = 1024
}

# Authentication worker processes
service auth-worker {
  # Number of auth worker processes
  # Should be at least the number of passdb/userdb connections
  user = root
  process_limit = 100
}

# Dictionary service (for quota and other data)
service dict {
  unix_listener dict {
    mode = 0666
    user = vmail
    group = mail
  }
}

# ----------------------------------------------------------------------------
# PROTOCOL-SPECIFIC SETTINGS
# ----------------------------------------------------------------------------

# IMAP-specific settings
protocol imap {
  # Maximum number of connections per IP address
  mail_max_userip_connections = 20
  
  # IMAP capabilities
  # IDLE: Server can notify client of new mail
  imap_idle_notify_interval = 2 mins
  
  # Maximum number of IMAP commands pipelined
  imap_max_line_length = 64k
}

# POP3-specific settings
protocol pop3 {
  # Maximum connections per IP
  mail_max_userip_connections = 10
  
  # Format for POP3 UIDL identifiers
  pop3_uidl_format = %08Xu%08Xv
  
  # Keep messages marked with \Seen flag
  pop3_save_uidl = yes
  
  # Don't leave messages on server
  pop3_delete_type = flag
}

# LMTP-specific settings
protocol lmtp {
  # Deliver to Spam folder if message is marked as spam
  # This works with Sieve filters
  postmaster_address = postmaster@PRIMARY_DOMAIN_PLACEHOLDER
  
  # Plugins to load for LMTP
  mail_plugins = $mail_plugins sieve
}

# ----------------------------------------------------------------------------
# PLUGIN CONFIGURATION
# ----------------------------------------------------------------------------

plugin {
  # Sieve mail filtering
  # Users can create filters to organize mail automatically
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
  
  # Global sieve scripts (before user scripts)
  # Uncomment to enable global spam filtering
  #sieve_before = /var/vmail/sieve/spam-global.sieve
  
  # Default sieve script for all users
  #sieve_default = /var/vmail/sieve/default.sieve
  
  # Quota settings (if enabled)
  # Limit each user to 5GB by default
  quota = maildir:User quota
  quota_rule = *:storage=5GB
  
  # Don't count Trash against quota
  quota_rule2 = Trash:storage=+10%%
  
  # Don't count Spam against quota  
  quota_rule3 = Spam:storage=+10%%
  
  # Quota warning at 90%
  quota_warning = storage=90%% quota-warning 90 %u
  quota_warning2 = storage=95%% quota-warning 95 %u
}

# Load plugins
mail_plugins = quota

# ----------------------------------------------------------------------------
# PERFORMANCE TUNING
# ----------------------------------------------------------------------------

# Cache mail headers and bodies for better performance
mail_cache_fields = flags
mail_always_cache_fields = imap.envelope

# Reduce disk I/O for better performance
mail_fsync = optimized

# Allow Dovecot to use sendfile() for better performance
mail_nfs_storage = no
mail_nfs_index = no

# Connection caching
imap_idle_notify_interval = 2 mins

# Process titles for debugging
process_title = yes

# ============================================================================
# END OF MAIN CONFIGURATION
# ============================================================================
DOVECOTCONF

    # Replace placeholders
    sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" "$DOVECOT_DIR/dovecot.conf"
    sed -i "s/PRIMARY_DOMAIN_PLACEHOLDER/$PRIMARY_DOMAIN/g" "$DOVECOT_DIR/dovecot.conf"
    
    # Create SQL configuration
    create_dovecot_sql_config
    
    # Create auth-sql.conf.ext if it doesn't exist
    touch "$DOVECOT_DIR/auth-sql.conf.ext"
    
    log_success "Dovecot configuration complete with extensive comments"
}

create_dovecot_sql_config() {
    log_step "Creating Dovecot SQL configuration..."
    
    cat > "$DOVECOT_DIR/dovecot-sql.conf.ext" << EOF
# ============================================================================
# DOVECOT SQL CONFIGURATION
# This file configures how Dovecot connects to the MySQL database
# to authenticate users and look up mailbox information
# ============================================================================

# ----------------------------------------------------------------------------
# DATABASE DRIVER
# ----------------------------------------------------------------------------

# Use MySQL driver
# Other options: pgsql (PostgreSQL), sqlite
driver = mysql

# ----------------------------------------------------------------------------
# DATABASE CONNECTION
# ----------------------------------------------------------------------------

# Connection string format:
# host=<hostname> port=<port> dbname=<database> user=<username> password=<password>
#
# IMPORTANT: Keep this file secure! It contains database credentials.
# Permissions should be: chmod 600 /etc/dovecot/dovecot-sql.conf.ext
connect = host=localhost port=3306 dbname=mail user=mailuser password=$DB_PASSWORD

# ----------------------------------------------------------------------------
# DEFAULT PASSWORD SCHEME
# ----------------------------------------------------------------------------

# How passwords are encrypted in the database
# Options:
#   SHA512-CRYPT: Strong, recommended (what we use)
#   SHA256-CRYPT: Strong, alternative
#   MD5-CRYPT: Weak, legacy
#   PLAIN: No encryption (NOT RECOMMENDED)
#   CRYPT: System crypt()
default_pass_scheme = SHA512-CRYPT

# ----------------------------------------------------------------------------
# PASSWORD QUERY
# ----------------------------------------------------------------------------

# SQL query to verify user passwords
# %u = full username (user@domain.com)
# %n = username part (user)
# %d = domain part (domain.com)
#
# This query must return:
#   - user: The username (used for logging)
#   - password: The encrypted password hash
#
# The query checks if the user exists and is enabled
password_query = SELECT email as user, password FROM mail_users WHERE email = '%u' AND enabled = 1

# ----------------------------------------------------------------------------
# USER QUERY
# ----------------------------------------------------------------------------

# SQL query to get user mailbox information
# This query must return:
#   - uid: Unix user ID (we use 5000 for vmail)
#   - gid: Unix group ID (we use 5000 for vmail)
#   - home: Home directory for the mailbox
#
# The mailbox path is: /var/vmail/domain.com/username/
user_query = SELECT 5000 as uid, 5000 as gid, '/var/vmail/%d/%n' as home, 'maildir:/var/vmail/%d/%n/Maildir' as mail FROM mail_users WHERE email = '%u' AND enabled = 1

# ----------------------------------------------------------------------------
# ITERATE QUERY (Optional)
# ----------------------------------------------------------------------------

# Query used by doveadm to list all users
# Useful for administrative tasks
iterate_query = SELECT email as user FROM mail_users WHERE enabled = 1

# ============================================================================
# SECURITY NOTES
# ============================================================================
#
# 1. This file contains sensitive database credentials
#    Set permissions: chmod 600 /etc/dovecot/dovecot-sql.conf.ext
#
# 2. The database user (mailuser) only needs SELECT permissions
#    It should NOT have INSERT, UPDATE, or DELETE permissions
#
# 3. Passwords in the database should ALWAYS be hashed
#    Never store plaintext passwords!
#
# 4. To generate a password hash for testing:
#    doveadm pw -s SHA512-CRYPT -p yourpassword
#
# ============================================================================
EOF

    chmod 600 "$DOVECOT_DIR/dovecot-sql.conf.ext"
    chown root:root "$DOVECOT_DIR/dovecot-sql.conf.ext"
    
    log_success "Dovecot SQL configuration created (mode 600)"
}

# ============================================================================
# SSL/TLS SETUP
# ============================================================================

setup_ssl_certificates() {
    print_section "SSL/TLS Certificates"
    
    log_info "SSL certificates are essential for secure mail communication"
    log_info "Let's Encrypt provides free, automated certificates"
    echo ""
    
    if ask_yes_no "Do you want to obtain Let's Encrypt certificates now?" "y"; then
        log_step "Installing Certbot..."
        
        # Install certbot with appropriate plugin for web server
        if [ "$WEB_SERVER" = "nginx" ] && [ "$WEBMAIL_CHOICE" != "none" ]; then
            install_package "certbot"
            # Try to install nginx plugin if available
            check_package_available "certbot-nginx" && install_package "certbot-nginx" || true
        elif [ "$WEB_SERVER" = "apache" ] && [ "$WEBMAIL_CHOICE" != "none" ]; then
            install_package "certbot"
            # Try to install apache plugin if available
            check_package_available "certbot-apache" && install_package "certbot-apache" || true
        else
            install_package "certbot"
        fi
        
        # Get certificate for mail hostname
        log_step "Obtaining certificate for $HOSTNAME..."
        
        # Stop services that might be using port 80
        systemctl stop postfix dovecot 2>/dev/null || true
        if [ "$WEB_SERVER" = "nginx" ]; then
            systemctl stop nginx 2>/dev/null || true
        elif [ "$WEB_SERVER" = "apache" ]; then
            systemctl stop apache2 httpd 2>/dev/null || true
        fi
        
        # Get certificate using standalone method
        certbot certonly --standalone \
            -d "$HOSTNAME" \
            --non-interactive \
            --agree-tos \
            --email "$ADMIN_EMAIL" \
            --keep-until-expiring
        
        if [ $? -eq 0 ]; then
            log_success "Certificate obtained for $HOSTNAME"
            
            # Update Postfix to use new certificates
            sed -i "s|smtpd_tls_cert_file.*|smtpd_tls_cert_file = /etc/letsencrypt/live/$HOSTNAME/fullchain.pem|" "$POSTFIX_DIR/main.cf"
            sed -i "s|smtpd_tls_key_file.*|smtpd_tls_key_file = /etc/letsencrypt/live/$HOSTNAME/privkey.pem|" "$POSTFIX_DIR/main.cf"
            
            # Update Dovecot to use new certificates
            sed -i "s|ssl_cert.*|ssl_cert = </etc/letsencrypt/live/$HOSTNAME/fullchain.pem|" "$DOVECOT_DIR/dovecot.conf"
            sed -i "s|ssl_key.*|ssl_key = </etc/letsencrypt/live/$HOSTNAME/privkey.pem|" "$DOVECOT_DIR/dovecot.conf"
        else
            log_error "Failed to obtain certificate for $HOSTNAME"
        fi
        
        # Get certificate for webmail domain if webmail is installed
        if [ "$WEBMAIL_CHOICE" != "none" ]; then
            local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
            log_step "Obtaining certificate for $WEBMAIL_DOMAIN..."
            
            certbot certonly --standalone \
                -d "$WEBMAIL_DOMAIN" \
                --non-interactive \
                --agree-tos \
                --email "$ADMIN_EMAIL" \
                --keep-until-expiring
            
            if [ $? -eq 0 ]; then
                log_success "Certificate obtained for $WEBMAIL_DOMAIN"
            else
                log_error "Failed to obtain certificate for $WEBMAIL_DOMAIN"
                log_warning "Webmail may not work properly without SSL"
            fi
        fi
        
        # Setup auto-renewal
        log_step "Setting up automatic renewal..."
        systemctl enable certbot.timer 2>/dev/null || (
            # Create cron job if systemd timer is not available
            (crontab -l 2>/dev/null || true; echo "0 0,12 * * * certbot renew --quiet") | crontab -
        )
        
        # Restart services
        systemctl start postfix dovecot 2>/dev/null || true
        if [ "$WEB_SERVER" = "nginx" ]; then
            systemctl start nginx 2>/dev/null || true
        elif [ "$WEB_SERVER" = "apache" ]; then
            systemctl start apache2 httpd 2>/dev/null || true
        fi
        
        log_success "SSL certificates configured"
    else
        log_warning "Skipping certificate generation"
        log_info "You can generate certificates later with:"
        echo "  certbot certonly --standalone -d $HOSTNAME -d ${DOMAINS[0]}"
        if [ "$WEBMAIL_CHOICE" != "none" ]; then
            echo "  certbot certonly --standalone -d mail.${PRIMARY_DOMAIN}"
        fi
    fi
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

start_and_enable_services() {
    print_section "Starting Services"
    
    local services=("mariadb" "postfix" "dovecot")
    
    if $ENABLE_SPAMASSASSIN; then
        services+=("spamassassin")
    fi
    
    if $ENABLE_CLAMAV; then
        services+=("clamav-daemon")
    fi
    
    if $ENABLE_DKIM; then
        services+=("opendkim")
    fi
    
    # Add webmail services if installed
    if [ "$WEBMAIL_CHOICE" != "none" ]; then
        # Add web server (nginx or apache)
        if [ "$WEB_SERVER" = "nginx" ]; then
            services+=("nginx")
        elif [ "$WEB_SERVER" = "apache" ]; then
            services+=("apache2" "httpd") # Try both names
        fi
        services+=("php-fpm")
        if [ "$WEBMAIL_CHOICE" = "sogo" ]; then
            services+=("sogo") # SOGo has its own service
        fi
    fi
    
    for service in "${services[@]}"; do
        log_step "Starting $service..."
        systemctl start "$service" 2>/dev/null || systemctl start "${service}.service" 2>/dev/null || log_warning "Could not start $service"
        systemctl enable "$service" 2>/dev/null || systemctl enable "${service}.service" 2>/dev/null || true
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_success "$service is running"
        else
            log_warning "$service may not be running - check manually"
        fi
    done
}

# ============================================================================
# FINAL INSTRUCTIONS
# ============================================================================

show_final_instructions() {
    print_section "Installation Complete!"
    
    cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║          Mail Server Installation Completed Successfully!        ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝${NC}

${BOLD}${WHITE}CONFIGURATION SUMMARY${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${CYAN}Primary Domain:${NC}     $PRIMARY_DOMAIN
${CYAN}Hostname:${NC}           $HOSTNAME
${CYAN}Admin Email:${NC}        $ADMIN_EMAIL
${CYAN}Total Domains:${NC}      ${#DOMAINS[@]}

${CYAN}Domains configured:${NC}
EOF

    for domain in "${DOMAINS[@]}"; do
        echo "  • $domain"
    done
    
    cat << EOF

${BOLD}${WHITE}SAVED CREDENTIALS${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${YELLOW}⚠  IMPORTANT: Save these credentials securely!${NC}

${CYAN}Database Password:${NC}
${WHITE}$DB_PASSWORD${NC}

${CYAN}PostfixAdmin Setup Password:${NC}
${WHITE}$POSTFIXADMIN_PASSWORD${NC}

EOF

    # Show webmail password if webmail was installed
    if [ "$WEBMAIL_CHOICE" != "none" ]; then
        cat << EOF
${CYAN}Webmail Database Password:${NC}
${WHITE}$WEBMAIL_PASSWORD${NC}

EOF
    fi
    
    cat << EOF
${BOLD}${WHITE}WEB INTERFACES${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${CYAN}PostfixAdmin:${NC}
${WHITE}https://$HOSTNAME/postfixadmin${NC}
Setup by visiting above URL and using setup password

EOF

    # Show webmail access info based on choice
    case "$WEBMAIL_CHOICE" in
        snappymail)
            cat << EOF
${CYAN}SnappyMail Webmail:${NC}
${WHITE}https://mail.$PRIMARY_DOMAIN${NC}

${YELLOW}First-time setup:${NC}
1. Visit the URL above
2. Follow the setup wizard
3. Configure these IMAP/SMTP settings:
   ${CYAN}IMAP Server:${NC}  localhost:993 (SSL)
   ${CYAN}SMTP Server:${NC}  localhost:587 (STARTTLS)

EOF
            ;;
        roundcube)
            cat << EOF
${CYAN}Roundcube Webmail:${NC}
${WHITE}https://mail.$PRIMARY_DOMAIN${NC}

${YELLOW}Login with your email account:${NC}
Use any email account you create via PostfixAdmin

EOF
            ;;
        sogo)
            cat << EOF
${CYAN}SOGo Groupware:${NC}
${WHITE}https://mail.$PRIMARY_DOMAIN/SOGo${NC}

${YELLOW}Features:${NC}
• Webmail
• Calendar (CalDAV)
• Contacts (CardDAV)
• ActiveSync for mobile devices

${YELLOW}Login with your email account:${NC}
Use any email account you create via PostfixAdmin

EOF
            ;;
    esac
    
    cat << EOF
${BOLD}${WHITE}NEXT STEPS${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${YELLOW}1.${NC} Configure DNS Records
   Add these records to your DNS:
   
   ${CYAN}MX Record:${NC}
   $PRIMARY_DOMAIN.  IN  MX  10  $HOSTNAME.
   
   ${CYAN}A Record:${NC}
   $HOSTNAME.  IN  A  <YOUR_SERVER_IP>
   
   ${CYAN}SPF Record:${NC}
   $PRIMARY_DOMAIN.  IN  TXT  "v=spf1 mx a ~all"
   
   ${CYAN}DMARC Record:${NC}
   _dmarc.$PRIMARY_DOMAIN.  IN  TXT  "v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
   
   ${CYAN}Autodiscover/Autoconfig Records (for each domain):${NC}
   autoconfig.$PRIMARY_DOMAIN.  IN  A  <YOUR_SERVER_IP>
   autodiscover.$PRIMARY_DOMAIN.  IN  A  <YOUR_SERVER_IP>

${YELLOW}2.${NC} Email Client Autoconfiguration
   Your server supports automatic configuration for:
   ${CYAN}• Thunderbird${NC} (Mozilla Autoconfig)
   ${CYAN}• Outlook${NC} (Microsoft Autodiscover)
   ${CYAN}• Apple Mail${NC} and other modern email clients
   
   ${GREEN}No manual setup needed!${NC} Just enter your email and password.
   Clients will automatically discover these settings:
   ${CYAN}IMAP:${NC} mail.$PRIMARY_DOMAIN:993 (SSL)
   ${CYAN}SMTP:${NC} mail.$PRIMARY_DOMAIN:587 (STARTTLS)

${YELLOW}3.${NC} Create Your First Email Account
   mysql -u root mail << 'SQLEOF'
   INSERT INTO mail_users (email, domain_id, password, enabled)
   VALUES ('user@$PRIMARY_DOMAIN', 
           (SELECT id FROM mail_domains WHERE domain = '$PRIMARY_DOMAIN'),
           ENCRYPT('your_password', CONCAT('\$6\$', SUBSTRING(SHA(RAND()), -16))),
           1);
   SQLEOF
   
   ${CYAN}Or use doveadm to generate a password hash:${NC}
   doveadm pw -s SHA512-CRYPT -p yourpassword

${YELLOW}4.${NC} Test Your Configuration
   ${CYAN}Check Postfix:${NC}
   postfix check
   postconf -n
   
   ${CYAN}Check Dovecot:${NC}
   doveconf -n
   
   ${CYAN}Test SMTP:${NC}
   telnet $HOSTNAME 25
   
   ${CYAN}Test IMAP:${NC}
   openssl s_client -connect $HOSTNAME:993

${YELLOW}5.${NC} Monitor Logs
   tail -f /var/log/mail.log
   journalctl -u postfix -f
   journalctl -u dovecot -f

${YELLOW}6.${NC} Configure Firewall
   ufw allow 25/tcp    # SMTP
   ufw allow 143/tcp   # IMAP
   ufw allow 993/tcp   # IMAPS
   ufw allow 587/tcp   # Submission
   ufw allow 465/tcp   # SMTPS (legacy)
   ufw allow 110/tcp   # POP3
   ufw allow 995/tcp   # POP3S
EOF

    # Add HTTPS if webmail is installed
    if [ "$WEBMAIL_CHOICE" != "none" ]; then
        cat << EOF
   ufw allow 80/tcp    # HTTP (for Let's Encrypt)
   ufw allow 443/tcp   # HTTPS (for webmail)
EOF
    fi
    
    cat << EOF

${BOLD}${WHITE}HELPFUL COMMANDS${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${CYAN}Check mail queue:${NC}          mailq
${CYAN}Flush mail queue:${NC}          postqueue -f
${CYAN}Test auth:${NC}                 doveadm auth test user@$PRIMARY_DOMAIN
${CYAN}Reload Postfix:${NC}            postfix reload
${CYAN}Reload Dovecot:${NC}            systemctl reload dovecot
${CYAN}Check service status:${NC}      systemctl status postfix dovecot

${BOLD}${WHITE}TROUBLESHOOTING${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${CYAN}Configuration files are heavily commented!${NC}
Read them to understand each setting:
  • $POSTFIX_DIR/main.cf
  • $POSTFIX_DIR/master.cf
  • $DOVECOT_DIR/dovecot.conf
  • $DOVECOT_DIR/dovecot-sql.conf.ext

${CYAN}Need help?${NC}
  • Check logs: /var/log/mail.log
  • Postfix docs: http://www.postfix.org/documentation.html
  • Dovecot docs: https://doc.dovecot.org/

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BOLD}${GREEN}Thank you for using the Interactive Mail Server Installer!${NC}

EOF
}

# ============================================================================
# AUTODISCOVER AND AUTOCONFIG
# ============================================================================

setup_autodiscover() {
    print_section "Setting up Email Client Autoconfiguration"
    
    log_info "Configuring Autodiscover (Outlook) and Autoconfig (Thunderbird)..."
    
    for DOMAIN in "${DOMAINS[@]}"; do
        log_step "Setting up autoconfiguration for $DOMAIN"
        
        # Create directory structure
        if [ "$WEB_SERVER" = "nginx" ]; then
            create_autodiscover_nginx "$DOMAIN"
        elif [ "$WEB_SERVER" = "apache" ]; then
            create_autodiscover_apache "$DOMAIN"
        fi
        
        # Create XML configuration files
        create_autoconfig_xml "$DOMAIN"
        create_autodiscover_xml "$DOMAIN"
    done
    
    log_success "Email client autoconfiguration setup complete"
}

create_autoconfig_xml() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    
    mkdir -p "${AUTOCONFIG_DIR}/mail"
    
    # Mozilla Thunderbird autoconfig
    cat > "${AUTOCONFIG_DIR}/mail/config-v1.1.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="${DOMAIN}">
    <domain>${DOMAIN}</domain>
    <displayName>${DOMAIN} Mail</displayName>
    <displayShortName>${DOMAIN}</displayShortName>
    
    <!-- Incoming Mail (IMAP) -->
    <incomingServer type="imap">
      <hostname>mail.${DOMAIN}</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    
    <!-- Incoming Mail (POP3) - Optional -->
    <incomingServer type="pop3">
      <hostname>mail.${DOMAIN}</hostname>
      <port>995</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    
    <!-- Outgoing Mail (SMTP) -->
    <outgoingServer type="smtp">
      <hostname>mail.${DOMAIN}</hostname>
      <port>587</port>
      <socketType>STARTTLS</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    
    <!-- Alternative SMTP (SSL) -->
    <outgoingServer type="smtp">
      <hostname>mail.${DOMAIN}</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    
    <documentation url="https://mail.${DOMAIN}/">
      <descr lang="en">General information about this mail server</descr>
    </documentation>
  </emailProvider>
</clientConfig>
EOF
    
    chmod 644 "${AUTOCONFIG_DIR}/mail/config-v1.1.xml"
    log_success "Created Thunderbird autoconfig for $DOMAIN"
}

create_autodiscover_xml() {
    local DOMAIN="$1"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    mkdir -p "${AUTODISCOVER_DIR}/autodiscover"
    mkdir -p "${AUTODISCOVER_DIR}/Autodiscover"
    
    # Microsoft Outlook Autodiscover
    local AUTODISCOVER_XML="${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml"
    cat > "$AUTODISCOVER_XML" << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>993</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>587</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>off</SSL>
        <Encryption>TLS</Encryption>
        <AuthRequired>on</AuthRequired>
        <UsePOPAuth>on</UsePOPAuth>
        <SMTPLast>off</SMTPLast>
      </Protocol>
      <Protocol>
        <Type>POP3</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>995</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>
XMLEOF
    
    # Replace placeholders with actual domain
    sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" "$AUTODISCOVER_XML"
    sed -i "s/EMAIL_PLACEHOLDER/%EMAILADDRESS%/g" "$AUTODISCOVER_XML"
    
    # Copy to both lowercase and uppercase paths (some clients expect different cases)
    cp "$AUTODISCOVER_XML" "${AUTODISCOVER_DIR}/Autodiscover/Autodiscover.xml"
    
    chmod 644 "${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml"
    chmod 644 "${AUTODISCOVER_DIR}/Autodiscover/Autodiscover.xml"
    
    log_success "Created Outlook Autodiscover for $DOMAIN"
}

create_autodiscover_nginx() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    # Thunderbird autoconfig vhost
    cat > "/etc/nginx/sites-available/autoconfig-${DOMAIN}" << EOF
server {
    listen 80;
    server_name autoconfig.${DOMAIN};
    
    root ${AUTOCONFIG_DIR};
    
    location /.well-known/autoconfig/mail/config-v1.1.xml {
        alias ${AUTOCONFIG_DIR}/mail/config-v1.1.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    location /mail/config-v1.1.xml {
        alias ${AUTOCONFIG_DIR}/mail/config-v1.1.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    access_log /var/log/nginx/autoconfig-${DOMAIN}-access.log;
    error_log /var/log/nginx/autoconfig-${DOMAIN}-error.log;
}
EOF
    
    # Outlook autodiscover vhost
    cat > "/etc/nginx/sites-available/autodiscover-${DOMAIN}" << EOF
server {
    listen 80;
    server_name autodiscover.${DOMAIN};
    
    root ${AUTODISCOVER_DIR};
    
    location ~ ^/(autodiscover|Autodiscover)/autodiscover.xml {
        alias ${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    access_log /var/log/nginx/autodiscover-${DOMAIN}-access.log;
    error_log /var/log/nginx/autodiscover-${DOMAIN}-error.log;
}
EOF
    
    # Enable sites
    ln -sf "/etc/nginx/sites-available/autoconfig-${DOMAIN}" "/etc/nginx/sites-enabled/"
    ln -sf "/etc/nginx/sites-available/autodiscover-${DOMAIN}" "/etc/nginx/sites-enabled/"
    
    log_success "Created nginx configuration for $DOMAIN autoconfiguration"
}

create_autodiscover_apache() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    # Determine Apache config directory
    local APACHE_CONF_DIR=""
    if [ -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF_DIR="/etc/apache2/sites-available"
    elif [ -d "/etc/httpd/conf.d" ]; then
        APACHE_CONF_DIR="/etc/httpd/conf.d"
    fi
    
    # Thunderbird autoconfig vhost
    cat > "${APACHE_CONF_DIR}/autoconfig-${DOMAIN}.conf" << EOF
<VirtualHost *:80>
    ServerName autoconfig.${DOMAIN}
    DocumentRoot ${AUTOCONFIG_DIR}
    
    <Directory ${AUTOCONFIG_DIR}>
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    Alias /.well-known/autoconfig/mail/config-v1.1.xml ${AUTOCONFIG_DIR}/mail/config-v1.1.xml
    Alias /mail/config-v1.1.xml ${AUTOCONFIG_DIR}/mail/config-v1.1.xml
    
    <Files "config-v1.1.xml">
        Header set Content-Type "application/xml; charset=utf-8"
    </Files>
    
    ErrorLog \${APACHE_LOG_DIR}/autoconfig-${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/autoconfig-${DOMAIN}-access.log combined
</VirtualHost>
EOF
    
    # Outlook autodiscover vhost
    cat > "${APACHE_CONF_DIR}/autodiscover-${DOMAIN}.conf" << EOF
<VirtualHost *:80>
    ServerName autodiscover.${DOMAIN}
    DocumentRoot ${AUTODISCOVER_DIR}
    
    <Directory ${AUTODISCOVER_DIR}>
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    AliasMatch (?i)^/(autodiscover|Autodiscover)/autodiscover.xml ${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml
    
    <Files "autodiscover.xml">
        Header set Content-Type "application/xml; charset=utf-8"
    </Files>
    
    ErrorLog \${APACHE_LOG_DIR}/autodiscover-${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/autodiscover-${DOMAIN}-access.log combined
</VirtualHost>
EOF
    
    # Enable sites (on Debian/Ubuntu)
    if [ -d "/etc/apache2/sites-enabled" ]; then
        a2ensite "autoconfig-${DOMAIN}" || true
        a2ensite "autodiscover-${DOMAIN}" || true
    fi
    
    log_success "Created Apache configuration for $DOMAIN autoconfiguration"
}

# ============================================================================
# WEBMAIL INSTALLATION
# ============================================================================

install_webmail() {
    if [ "$WEBMAIL_CHOICE" = "none" ]; then
        log_info "Webmail installation skipped"
        return
    fi
    
    print_section "Installing Webmail Client"
    
    # Install web server if not already installed
    log_step "Setting up web server..."
    if [ "$WEB_SERVER" = "nginx" ]; then
        install_package "nginx"
    elif [ "$WEB_SERVER" = "apache" ]; then
        install_package "apache"
    fi
    
    # Install common PHP dependencies
    log_step "Installing PHP and dependencies..."
    install_package "php"
    install_package "wget"
    install_package "unzip"
    
    case "$WEBMAIL_CHOICE" in
        snappymail)
            install_snappymail
            ;;
        roundcube)
            install_roundcube
            ;;
        sogo)
            install_sogo
            ;;
    esac
}

install_snappymail() {
    log_step "Installing SnappyMail..."
    
    # SnappyMail is a modern, fast, and lightweight webmail client
    # It doesn't require a database - it uses file storage
    # https://snappymail.eu/
    
    local SNAPPYMAIL_VERSION="latest"
    local INSTALL_DIR="/var/www/snappymail"
    local DOWNLOAD_URL="https://api.github.com/repos/the-djmaze/snappymail/releases/latest"
    
    # Get the latest release download URL
    log_info "Fetching latest SnappyMail release..."
    local ASSET_URL=$(curl -s "$DOWNLOAD_URL" | grep "browser_download_url.*snappymail.*zip" | head -1 | cut -d '"' -f 4)
    
    if [ -z "$ASSET_URL" ]; then
        log_error "Could not fetch SnappyMail download URL"
        return 1
    fi
    
    # Download SnappyMail
    log_step "Downloading SnappyMail..."
    cd /tmp
    wget -q "$ASSET_URL" -O snappymail.zip
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Extract
    log_step "Extracting SnappyMail..."
    unzip -q snappymail.zip -d "$INSTALL_DIR"
    rm snappymail.zip
    
    # Set permissions
    # SnappyMail needs to write to its data directory
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    
    # Create data directory with write permissions
    mkdir -p "$INSTALL_DIR/data"
    chmod 750 "$INSTALL_DIR/data"
    
    log_success "SnappyMail installed to $INSTALL_DIR"
    
    # Configure web server virtual host
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_snappymail_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_snappymail_apache
    fi
}

install_roundcube() {
    log_step "Installing Roundcube..."
    
    # Roundcube is a mature, feature-rich webmail client
    # It requires MySQL database and is very customizable
    # https://roundcube.net/
    
    install_package "roundcube"
    
    # Create database for Roundcube
    log_step "Creating Roundcube database..."
    mysql -u root -p"$DB_PASSWORD" << EOSQL
CREATE DATABASE IF NOT EXISTS roundcubemail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost' IDENTIFIED BY '$WEBMAIL_PASSWORD';
FLUSH PRIVILEGES;
EOSQL
    
    # Import Roundcube database schema
    local RC_SQL="/usr/share/roundcube/SQL/mysql.initial.sql"
    if [ -f "$RC_SQL" ]; then
        mysql -u root -p"$DB_PASSWORD" roundcubemail < "$RC_SQL"
        log_success "Roundcube database initialized"
    else
        log_warning "Roundcube SQL file not found at $RC_SQL"
    fi
    
    # Configure Roundcube
    configure_roundcube
    
    # Configure web server
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_roundcube_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_roundcube_apache
    fi
    
    log_success "Roundcube installed"
}

install_sogo() {
    log_step "Installing SOGo..."
    
    # SOGo is a full groupware solution with webmail, calendar, and contacts
    # It supports ActiveSync for mobile devices
    # https://sogo.nu/
    
    install_package "sogo"
    
    # Create database for SOGo
    log_step "Creating SOGo database..."
    mysql -u root -p"$DB_PASSWORD" << EOSQL
CREATE DATABASE IF NOT EXISTS sogo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON sogo.* TO 'sogo'@'localhost' IDENTIFIED BY '$WEBMAIL_PASSWORD';
FLUSH PRIVILEGES;
EOSQL
    
    # Configure SOGo
    configure_sogo
    
    # Configure web server
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_sogo_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_sogo_apache
    fi
    
    log_success "SOGo installed"
}

# ============================================================================
# WEBMAIL CONFIGURATION
# ============================================================================

configure_snappymail_nginx() {
    log_step "Configuring nginx for SnappyMail..."
    
    local NGINX_CONF="/etc/nginx/sites-available/snappymail"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
# ============================================================================
# SNAPPYMAIL WEBMAIL - NGINX CONFIGURATION
# ============================================================================
# This configuration serves SnappyMail webmail client
# URL: https://mail.example.com/snappymail
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    # SSL Certificates (will be generated by Certbot)
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Document root
    root /var/www/snappymail;
    index index.php index.html;
    
    # Logging
    access_log /var/log/nginx/snappymail-access.log;
    error_log /var/log/nginx/snappymail-error.log;
    
    # Main location
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Security: Deny access to sensitive files
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /data/ {
        deny all;
    }
    
    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOFNGINX
    
    # Replace placeholder with actual domain
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    
    # Enable site
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for SnappyMail"
}

configure_snappymail_apache() {
    log_step "Configuring Apache for SnappyMail..."
    
    local APACHE_CONF="/etc/apache2/sites-available/snappymail.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    # Handle different Apache config paths
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/snappymail.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
# ============================================================================
# SNAPPYMAIL WEBMAIL - APACHE CONFIGURATION
# ============================================================================
# This configuration serves SnappyMail webmail client
# URL: https://mail.example.com
# ============================================================================

<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    
    # Redirect HTTP to HTTPS
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    # SSL Configuration (will be managed by Certbot)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder on
    SSLCompression off
    SSLSessionTickets off
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    # Document Root
    DocumentRoot /var/www/snappymail
    
    <Directory /var/www/snappymail>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>
    
    # Deny access to data directory
    <Directory /var/www/snappymail/data>
        Require all denied
    </Directory>
    
    # PHP Configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/snappymail-error.log
    CustomLog ${APACHE_LOG_DIR}/snappymail-access.log combined
</VirtualHost>
EOFAPACHE
    
    # Replace placeholder with actual domain
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    # Enable required modules
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl rewrite proxy_fcgi setenvif headers
        a2ensite snappymail
    fi
    
    # Test and reload Apache
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for SnappyMail"
}

configure_roundcube() {
    log_step "Configuring Roundcube..."
    
    local RC_CONFIG="/etc/roundcube/config.inc.php"
    
    # Backup original config if exists
    [ -f "$RC_CONFIG" ] && cp "$RC_CONFIG" "${RC_CONFIG}.backup"
    
    cat > "$RC_CONFIG" << EOFRC
<?php
/**
 * ============================================================================
 * ROUNDCUBE WEBMAIL CONFIGURATION
 * ============================================================================
 * This file configures Roundcube to connect to your mail server
 * ============================================================================
 */

// --------------------------------------------------
// DATABASE CONNECTION
// --------------------------------------------------
\$config['db_dsnw'] = 'mysql://roundcube:$WEBMAIL_PASSWORD@localhost/roundcubemail';

// --------------------------------------------------
// IMAP CONNECTION
// --------------------------------------------------
// Connect to Dovecot IMAP server
\$config['imap_host'] = 'ssl://localhost:993';
\$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// --------------------------------------------------
// SMTP CONNECTION
// --------------------------------------------------
// Connect to Postfix SMTP server for sending mail
\$config['smtp_host'] = 'tls://localhost:587';
\$config['smtp_user'] = '%u'; // Use IMAP username
\$config['smtp_pass'] = '%p'; // Use IMAP password
\$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// --------------------------------------------------
// GENERAL SETTINGS
// --------------------------------------------------
\$config['des_key'] = '$(openssl rand -base64 24)'; // Encryption key for session
\$config['product_name'] = 'Webmail'; // Name shown in interface
\$config['useragent'] = 'Roundcube Webmail'; // User agent
\$config['support_url'] = '';

// --------------------------------------------------
// USER INTERFACE
// --------------------------------------------------
\$config['language'] = 'en_US';
\$config['skin'] = 'elastic'; // Modern responsive skin
\$config['enable_spellcheck'] = true;

// --------------------------------------------------
// SECURITY
// --------------------------------------------------
\$config['session_lifetime'] = 30; // Minutes
\$config['ip_check'] = true; // Check IP for session security
\$config['identities_level'] = 0; // Users can create multiple identities

// --------------------------------------------------
// PLUGINS
// --------------------------------------------------
\$config['plugins'] = array(
    'archive',
    'zipdownload',
    'managesieve', // For managing mail filters
);

EOFRC
    
    log_success "Roundcube configured"
}

configure_roundcube_nginx() {
    log_step "Configuring Nginx for Roundcube..."
    
    local NGINX_CONF="/etc/nginx/sites-available/roundcube"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
# ============================================================================
# ROUNDCUBE WEBMAIL - NGINX CONFIGURATION
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    
    # SSL Session Configuration
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    root /usr/share/roundcube;
    index index.php;
    
    access_log /var/log/nginx/roundcube-access.log;
    error_log /var/log/nginx/roundcube-error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(ht|git|svn) {
        deny all;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOFNGINX
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for Roundcube"
}

configure_roundcube_apache() {
    log_step "Configuring Apache for Roundcube..."
    
    local APACHE_CONF="/etc/apache2/sites-available/roundcube.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/roundcube.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    
    DocumentRoot /usr/share/roundcube
    
    <Directory /usr/share/roundcube>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
    </Directory>
    
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    ErrorLog ${APACHE_LOG_DIR}/roundcube-error.log
    CustomLog ${APACHE_LOG_DIR}/roundcube-access.log combined
</VirtualHost>
EOFAPACHE
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl rewrite proxy_fcgi setenvif
        a2ensite roundcube
    fi
    
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for Roundcube"
}

configure_sogo() {
    log_step "Configuring SOGo..."
    
    local SOGO_CONFIG="/etc/sogo/sogo.conf"
    
    # Backup original config
    [ -f "$SOGO_CONFIG" ] && cp "$SOGO_CONFIG" "${SOGO_CONFIG}.backup"
    
    cat > "$SOGO_CONFIG" << EOFSOGO
/**
 * ============================================================================
 * SOGO GROUPWARE CONFIGURATION
 * ============================================================================
 * SOGo is a full groupware solution with webmail, calendar, and contacts
 * It supports ActiveSync for mobile device synchronization
 * ============================================================================
 */

{
  /* Database Configuration */
  SOGoProfileURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_user_profile";
  OCSFolderInfoURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_folder_info";
  OCSSessionsFolderURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_sessions_folder";
  
  /* Mail Server Configuration */
  SOGoIMAPServer = "localhost";
  SOGoSieveServer = "sieve://localhost:4190";
  SOGoSMTPServer = "localhost";
  SOGoMailDomain = "$PRIMARY_DOMAIN";
  SOGoMailingMechanism = "smtp";
  
  /* Authentication */
  SOGoForceExternalLoginWithEmail = YES;
  SOGoPasswordChangeEnabled = NO;
  
  /* Web Interface */
  SOGoPageTitle = "Mail";
  SOGoLanguage = "English";
  SOGoTimeZone = "UTC";
  
  /* ActiveSync for Mobile Devices */
  SOGoEnableEAS = YES;
  
  /* Calendar */
  SOGoFirstDayOfWeek = 0; // 0=Sunday, 1=Monday
  SOGoCalendarDefaultRoles = (
    "PublicViewer",
    "ConfidentialDAndTViewer"
  );
  
  /* Security */
  SOGoSessionTimeOut = 1800; // 30 minutes
}
EOFSOGO
    
    log_success "SOGo configured"
}

configure_sogo_nginx() {
    log_step "Configuring Nginx for SOGo..."
    
    local NGINX_CONF="/etc/nginx/sites-available/sogo"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    access_log /var/log/nginx/sogo-access.log;
    error_log /var/log/nginx/sogo-error.log;
    
    # SOGo runs on port 20000 by default
    location / {
        proxy_pass http://127.0.0.1:20000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # ActiveSync
    location /Microsoft-Server-ActiveSync {
        proxy_pass http://127.0.0.1:20000/Microsoft-Server-ActiveSync;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOFNGINX
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for SOGo"
}

configure_sogo_apache() {
    log_step "Configuring Apache for SOGo..."
    
    local APACHE_CONF="/etc/apache2/sites-available/sogo.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/sogo.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    
    # SOGo proxy configuration
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:20000/
    ProxyPassReverse / http://127.0.0.1:20000/
    
    # ActiveSync
    ProxyPass /Microsoft-Server-ActiveSync http://127.0.0.1:20000/Microsoft-Server-ActiveSync
    ProxyPassReverse /Microsoft-Server-ActiveSync http://127.0.0.1:20000/Microsoft-Server-ActiveSync
    
    ErrorLog ${APACHE_LOG_DIR}/sogo-error.log
    CustomLog ${APACHE_LOG_DIR}/sogo-access.log combined
</VirtualHost>
EOFAPACHE
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl proxy proxy_http headers
        a2ensite sogo
    fi
    
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for SOGo"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header
    
    # Check requirements
    check_root
    detect_distribution
    pause_for_user
    
    # Collect configuration
    collect_basic_info
    collect_component_choices
    generate_passwords
    
    # Test DNS and show configuration needed
    test_dns_records
    show_dns_configuration
    
    # Confirm installation
    print_section "Ready to Install"
    log_warning "The installation will now begin"
    log_info "This may take several minutes depending on your internet speed"
    echo ""
    
    if ! ask_yes_no "Do you want to proceed with the installation?" "y"; then
        log_warning "Installation cancelled by user"
        exit 0
    fi
    
    # Perform installation
    update_package_cache
    install_core_packages
    install_optional_packages
    setup_database
    configure_postfix
    configure_dovecot
    install_webmail
    setup_autodiscover
    setup_ssl_certificates
    start_and_enable_services
    
    # Show final instructions
    show_final_instructions
}

# Run main function
main

exit 0
