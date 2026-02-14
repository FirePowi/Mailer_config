#!/usr/bin/env bash
#
# Interactive Mail Server Installation and Configuration Script
# Modular architecture - Easy to understand and maintain
#
# Usage: sudo ./install.sh
# No prior knowledge needed - we guide you through everything!
# Supports resuming from interruptions
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
source "${LIB_DIR}/progress.sh"  # Progress tracking

# We need functions from the monolithic script for now
if [ -f "${SCRIPT_DIR}/install-mail-server.sh" ]; then
    source "${SCRIPT_DIR}/install-mail-server.sh"
else
    echo "ERROR: ${SCRIPT_DIR}/install-mail-server.sh not found"
    exit 1
fi

# ============================================================================
# INSTALLATION STEP FUNCTIONS
# ============================================================================

run_detect_system() {
    if should_skip_step "detect_system"; then
        log_info "Skipping: System detection (already completed)"
        return 0
    fi
    
    check_root
    detect_distribution
    save_progress "detect_system" "completed"
}

run_collect_info() {
    if should_skip_step "collect_info"; then
        log_info "Skipping: User configuration (already completed)"
        return 0
    fi
    
    collect_basic_info
    collect_component_choices
    generate_passwords
    save_progress "collect_info" "completed"
}

run_update_packages() {
    if should_skip_step "update_packages"; then
        log_info "Skipping: Package cache update (already completed)"
        return 0
    fi
    
    update_package_cache
    save_progress "update_packages" "completed"
}

run_install_core() {
    if should_skip_step "install_core"; then
        log_info "Skipping: Core packages installation (already completed)"
        return 0
    fi
    
    install_core_packages
    save_progress "install_core" "completed"
}

run_install_optional() {
    if should_skip_step "install_optional"; then
        log_info "Skipping: Optional packages installation (already completed)"
        return 0
    fi
    
    install_optional_packages
    save_progress "install_optional" "completed"
}

run_setup_database() {
    if should_skip_step "setup_database"; then
        log_info "Skipping: Database setup (already completed)"
        return 0
    fi
    
    setup_database
    save_progress "setup_database" "completed"
}

run_configure_postfix() {
    if should_skip_step "configure_postfix"; then
        log_info "Skipping: Postfix configuration (already completed)"
        return 0
    fi
    
    configure_postfix
    save_progress "configure_postfix" "completed"
}

run_configure_dovecot() {
    if should_skip_step "configure_dovecot"; then
        log_info "Skipping: Dovecot configuration (already completed)"
        return 0
    fi
    
    configure_dovecot
    save_progress "configure_dovecot" "completed"
}

run_setup_ssl() {
    if should_skip_step "setup_ssl"; then
        log_info "Skipping: SSL certificate setup (already completed)"
        return 0
    fi
    
    setup_ssl_certificates
    save_progress "setup_ssl" "completed"
}

run_setup_autodiscover() {
    if should_skip_step "setup_autodiscover"; then
        log_info "Skipping: Autodiscover setup (already completed)"
        return 0
    fi
    
    setup_autodiscover
    save_progress "setup_autodiscover" "completed"
}

run_install_webmail() {
    if should_skip_step "install_webmail"; then
        log_info "Skipping: Webmail installation (already completed)"
        return 0
    fi
    
    install_webmail
    save_progress "install_webmail" "completed"
}

run_finalize() {
    if should_skip_step "finalize"; then
        log_info "Skipping: Finalization (already completed)"
        return 0
    fi
    
    start_and_enable_services
    show_final_instructions
    save_progress "finalize" "completed"
    
    # Clear progress on successful completion
    log_success "Installation completed successfully!"
    clear_progress
}

# ============================================================================
# MAIN INSTALLATION ORCHESTRATION
# ============================================================================

main() {
    print_header
    
    # Check for previous progress and optionally resume
    local resume_from
    resume_from=$(prompt_resume)
    
    if [[ $? -ne 0 ]]; then
        log_warning "Installation cancelled"
        exit 0
    fi
    
    # Run all installation steps
    run_detect_system
    pause_for_user
    
    run_collect_info
    
    # DNS Configuration Guide
    test_dns_records
    interactive_dns_setup
    show_dns_configuration
    
    # Confirm before installation
    print_section "Ready to Install"
    log_warning "The installation will now begin"
    log_info "This may take several minutes depending on your internet speed"
    log_info "You can safely interrupt (Ctrl+C) and resume later"
    echo ""
    
    if ! ask_yes_no "Do you want to proceed with the installation?" "y"; then
        log_warning "Installation cancelled by user"
        exit 0
    fi
    
    # Execute installation steps
    run_update_packages
    run_install_core
    run_install_optional
    run_setup_database
    run_configure_postfix
    run_configure_dovecot
    run_setup_ssl
    run_setup_autodiscover
    run_install_webmail
    run_finalize
}

# Run main function
main


exit 0
