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
source "${LIB_DIR}/config.sh"       # Configuration variables
source "${LIB_DIR}/i18n.sh"         # Internationalization
source "${LIB_DIR}/ui.sh"           # UI functions and colors
source "${LIB_DIR}/system.sh"       # System detection
source "${LIB_DIR}/packages.sh"     # Package management
source "${LIB_DIR}/dns.sh"          # DNS configuration helper
source "${LIB_DIR}/input.sh"        # User input collection
source "${LIB_DIR}/progress.sh"     # Progress tracking
source "${LIB_DIR}/database.sh"     # Database setup
source "${LIB_DIR}/postfix.sh"      # Postfix configuration
source "${LIB_DIR}/dovecot.sh"      # Dovecot configuration
source "${LIB_DIR}/ssl.sh"          # SSL/TLS certificates
source "${LIB_DIR}/autodiscover.sh" # Email client autodiscovery
source "${LIB_DIR}/webmail.sh"      # Webmail installation
source "${LIB_DIR}/services.sh"     # Service management

# ============================================================================
# INSTALLATION STEP FUNCTIONS
# ============================================================================

run_detect_system() {
    if should_skip_step "detect_system"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.detect_system')")"
        return 0
    fi
    
    check_root
    detect_distribution
    save_progress "detect_system" "completed"
}

run_collect_info() {
    if should_skip_step "collect_info"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.collect_info')")"
        return 0
    fi
    
    collect_basic_info
    collect_component_choices
    generate_passwords
    save_progress "collect_info" "completed"
}

run_update_packages() {
    if should_skip_step "update_packages"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.update_packages')")"
        return 0
    fi
    
    update_package_cache
    save_progress "update_packages" "completed"
}

run_install_core() {
    if should_skip_step "install_core"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.install_core')")"
        return 0
    fi
    
    install_core_packages
    save_progress "install_core" "completed"
}

run_install_optional() {
    if should_skip_step "install_optional"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.install_optional')")"
        return 0
    fi
    
    install_optional_packages
    save_progress "install_optional" "completed"
}

run_setup_database() {
    if should_skip_step "setup_database"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.setup_database')")"
        return 0
    fi
    
    setup_database
    save_progress "setup_database" "completed"
}

run_configure_postfix() {
    if should_skip_step "configure_postfix"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.configure_postfix')")"
        return 0
    fi
    
    configure_postfix
    save_progress "configure_postfix" "completed"
}

run_configure_dovecot() {
    if should_skip_step "configure_dovecot"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.configure_dovecot')")"
        return 0
    fi
    
    configure_dovecot
    save_progress "configure_dovecot" "completed"
}

run_setup_ssl() {
    if should_skip_step "setup_ssl"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.setup_ssl')")"
        return 0
    fi
    
    setup_ssl_certificates
    save_progress "setup_ssl" "completed"
}

run_setup_autodiscover() {
    if should_skip_step "setup_autodiscover"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.setup_autodiscover')")"
        return 0
    fi
    
    setup_autodiscover
    save_progress "setup_autodiscover" "completed"
}

run_install_webmail() {
    if should_skip_step "install_webmail"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.install_webmail')")"
        return 0
    fi
    
    install_webmail
    save_progress "install_webmail" "completed"
}

run_finalize() {
    if should_skip_step "finalize"; then
        log_info "$(t 'skip.already_completed' "$(t 'step.finalize')")"
        return 0
    fi
    
    start_and_enable_services
    show_final_instructions
    save_progress "finalize" "completed"
    
    # Clear progress on successful completion
    log_success "$(t 'install.completed')"
    clear_progress
}

# ============================================================================
# MAIN INSTALLATION ORCHESTRATION
# ============================================================================

main() {
    print_header
    
    # Check for previous progress and optionally resume
    echo ""
    log_info "$(t 'progress.checking')"
    
    local resume_from
    resume_from=$(prompt_resume)
    local resume_status=$?
    
    if [[ $resume_status -ne 0 ]]; then
        log_warning "$(t 'progress.cancelled')"
        exit 0
    fi
    
    if [[ -z "$resume_from" ]]; then
        echo ""
        log_info "$(t 'progress.starting_fresh')"
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
    log_warning "$(t 'install.warning')"
    log_info "$(t 'install.duration')"
    log_info "$(t 'install.interruptible')"
    echo ""
    
    if ! ask_yes_no "$(t 'install.continue')" "y"; then
        log_warning "$(t 'progress.cancelled')"
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
