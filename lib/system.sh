#!/usr/bin/env bash
#
# System Detection Library
# Handles distribution detection and root checking
#

# Source UI library for colors and formatting functions
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ui.sh"

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
