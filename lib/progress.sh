#!/usr/bin/env bash
#
# Progress Tracking Library
# Saves and loads installation progress to allow resuming
#

# Source UI library for colors and formatting
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ui.sh"

# Progress tracking file
PROGRESS_FILE="${PROGRESS_FILE:-/var/tmp/mail-server-install-progress.state}"

# Available installation steps
declare -a INSTALL_STEPS=(
    "detect_system"
    "collect_info"
    "update_packages"
    "install_core"
    "install_optional"
    "setup_database"
    "configure_postfix"
    "configure_dovecot"
    "setup_ssl"
    "setup_autodiscover"
    "install_webmail"
    "finalize"
)

#==============================================================================
# Progress Management Functions
#==============================================================================

save_progress() {
    local step="$1"
    local status="${2:-completed}"  # completed, failed, skipped
    
    echo "$step:$status:$(date +%s)" >> "$PROGRESS_FILE"
    log_info "Progress saved: $step ($status)"
}

load_progress() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        return 1
    fi
    
    # Return the last completed step
    local last_step
    last_step=$(grep ":completed:" "$PROGRESS_FILE" | tail -1 | cut -d: -f1)
    echo "$last_step"
}

check_step_completed() {
    local step="$1"
    
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        return 1
    fi
    
    grep -q "^$step:completed:" "$PROGRESS_FILE"
}

get_next_step() {
    local last_step="$1"
    
    if [[ -z "$last_step" ]]; then
        printf "%s" "${INSTALL_STEPS[0]}"
        return
    fi
    
    local found=false
    for step in "${INSTALL_STEPS[@]}"; do
        if [[ "$found" == true ]]; then
            printf "%s" "$step"
            return
        fi
        if [[ "$step" == "$last_step" ]]; then
            found=true
        fi
    done
    
    printf ""  # No more steps
}

show_progress_summary() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        log_info "$(t 'progress.no_previous')"
        return
    fi
    
    print_section "$(t 'progress.title')"
    
    echo -e "${CYAN}$(t 'progress.completed_steps')${NC}"
    while IFS=: read -r step status timestamp; do
        local date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
        
        case "$status" in
            completed)
                echo -e "  ${GREEN}✓${NC} $step ${WHITE}($date_str)${NC}"
                ;;
            failed)
                echo -e "  ${RED}✗${NC} $step ${WHITE}($date_str)${NC}"
                ;;
            skipped)
                echo -e "  ${YELLOW}○${NC} $step ${WHITE}(skipped, $date_str)${NC}"
                ;;
        esac
    done < "$PROGRESS_FILE"
    
    echo ""
}

clear_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        rm -f "$PROGRESS_FILE"
        log_success "Installation progress cleared"
    fi
}

prompt_resume() {
    local last_step
    last_step=$(load_progress)
    
    if [[ -z "$last_step" ]]; then
        log_info "$(t 'progress.no_previous')"
        return 0  # No previous progress, start fresh
    fi
    
    local next_step
    next_step=$(get_next_step "$last_step")
    
    if [[ -z "$next_step" ]]; then
        show_progress_summary
        log_success "$(t 'progress.completed')"
        echo ""
        if ask_yes_no "$(t 'progress.fresh_question')" "n"; then
            clear_progress
            return 0
        else
            return 1
        fi
    fi
    
    log_warning "$(t 'progress.interrupted') $last_step"
    echo ""
    
    if ask_yes_no "$(t 'progress.resume_question')" "y"; then
        echo ""
        show_progress_summary
        log_success "$(t 'progress.resuming') $next_step"
        printf "%s" "$next_step"  # Return the next step to resume from
        return 0
    else
        if ask_yes_no "$(t 'progress.fresh_question')" "n"; then
            clear_progress
            return 0
        else
            log_info "$(t 'progress.cancelled')"
            return 1
        fi
    fi
}

should_skip_step() {
    local step="$1"
    
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        return 1  # No progress file, don't skip
    fi
    
    check_step_completed "$step"
}
