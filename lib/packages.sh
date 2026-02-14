#!/usr/bin/env bash
#
# Package Management Library
# Handles package name mapping and installation across distributions
#

# Source UI library for colors and formatting
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ui.sh"

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
                php) echo "php php-fpm php-mysql php-mbstring php-json php-xml php-curl" ;;
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
                php) echo "php php-fpm php-mysqlnd php-mbstring php-json php-xml" ;;
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
                php) echo "php php-fpm php-json" ;;
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
                php) echo "php7 php7-fpm php7-mysql php7-mbstring" ;;
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
# PACKAGE MANAGEMENT FUNCTIONS
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
            # Try to install all packages, but don't fail if some are unavailable
            local failed_packages=""
            for pkg in $actual_packages; do
                if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" 2>/dev/null; then
                    log_warning "Package $pkg not available, skipping"
                    failed_packages="$failed_packages $pkg"
                fi
            done
            if [[ -n "$failed_packages" ]]; then
                log_info "Some packages were skipped:$failed_packages"
            fi
            ;;
        yum|dnf)
            $PACKAGE_MANAGER install -y -q $actual_packages 2>/dev/null || log_warning "Some packages may not have been installed"
            ;;
        pacman)
            pacman -S --noconfirm --needed $actual_packages 2>/dev/null || log_warning "Some packages may not have been installed"
            ;;
        zypper)
            zypper install -y $actual_packages 2>/dev/null || log_warning "Some packages may not have been installed"
            ;;
    esac
    
    log_success "Installed: $package_name"
}


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

install_core_packages() {
    print_section "Installing Core Packages"
    
    install_package "postfix"
    install_package "postfix-mysql"
    install_package "dovecot"
    install_package "dovecot-mysql"
    install_package "mysql-server"
    install_package "mysql-client"
    
    log_success "Core packages installed"
}

install_optional_packages() {
    print_section "Installing Optional Packages"
    
    if [[ "$ENABLE_SPAMASSASSIN" == true ]]; then
        install_package "spamassassin"
    fi
    
    if [[ "$ENABLE_CLAMAV" == true ]]; then
        install_package "clamav"
    fi
    
    if [[ "$ENABLE_POLICYD_SPF" == true ]]; then
        install_package "postfix-policyd-spf"
    fi
    
    if [[ "$ENABLE_DKIM" == true ]]; then
        install_package "opendkim"
    fi
    
    if [[ "$ENABLE_RSPAMD" == true ]]; then
        install_package "rspamd"
    fi
    
    log_success "Optional packages installed"
}
