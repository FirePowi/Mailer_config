#!/usr/bin/env bash
#
# Interactive Mail Server Installation and Configuration Script
# Modular architecture - Easy to understand and maintain
#
# Usage: sudo ./install.sh
# No prior knowledge needed - we guide you through everything!
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# Load all library modules
source "${LIB_DIR}/config.sh"    # Configuration variables
source "${LIB_DIR}/ui.sh"        # UI functions and colors
source "${LIB_DIR}/system.sh"    # System detection
source "${LIB_DIR}/packages.sh"  # Package management
source "${LIB_DIR}/dns.sh"       # DNS configuration helper
source "${LIB_DIR}/input.sh"     # User input collection

# Load configuration modules (these will be sourced dynamically)
# We keep the old monolithic file for now and will split it further
# For postfix, dovecot, webmail, ssl, autodiscover configuration

# ============================================================================
# MAIN INSTALLATION ORCHESTRATION
# ============================================================================

main() {
    print_header
    
    # Phase 1: System Check and Detection
    check_root
    detect_distribution
    pause_for_user
    
    # Phase 2: User Configuration
    collect_basic_info
    collect_component_choices
    generate_passwords
    
    # Phase 3: DNS Configuration Guide
    test_dns_records
    interactive_dns_setup
    show_dns_configuration
    
    # Phase 4: Confirm and Install
    print_section "Ready to Install"
    log_warning "The installation will now begin"
    log_info "This may take several minutes depending on your internet speed"
    echo ""
    
    if ! ask_yes_no "Do you want to proceed with the installation?" "y"; then
        log_warning "Installation cancelled by user"
        exit 0
    fi
    
    # Phase 5: Package Installation
    update_package_cache
    install_core_packages
    install_optional_packages
    
    # Phase 6: Configuration (using old monolithic functions for now)
    # These will be moved to separate modules in the next iteration
    if [ -f "${SCRIPT_DIR}/install-mail-server.sh" ]; then
        source "${SCRIPT_DIR}/install-mail-server.sh"
        
        setup_database
        configure_postfix
        configure_dovecot
        install_webmail
        setup_autodiscover
        setup_ssl_certificates
    else
        log_error "Configuration functions not yet migrated to modular system"
        log_info "Please use install-mail-server.sh directly for now"
        exit 1
    fi
    start_and_enable_services
    
    # Phase 7: Final Instructions
    show_final_instructions
}

# Run main function
main

exit 0
