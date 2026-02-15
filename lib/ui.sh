#!/usr/bin/env bash
#
# UI Functions Library
# Provides colors, logging, and user interaction functions
#

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
# UI FUNCTIONS
# ============================================================================

print_header() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo -e "╔═══════════════════════════════════════════════════════════════════════╗"
    echo -e "║                                                                       ║"
    echo -e "║             Interactive Mail Server Installation Script               ║"
    echo -e "║                                                                       ║"
    echo -e "║        Postfix + Dovecot + SpamAssassin + Policyd-SPF + More          ║"
    echo -e "║                                                                       ║"
    echo -e "╚═══════════════════════════════════════════════════════════════════════╝"
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
        echo -ne "${YELLOW}${question}${NC} ${WHITE}[${default}]${NC} "
    else
        echo -ne "${YELLOW}${question}${NC} "
    fi
    
    read -r response
    echo "${response:-$default}"
}

ask_yes_no() {
    local question="$1"
    local default="${2:-y}"
    local response
    
    if [[ "$default" == "y" ]]; then
        echo -ne "${YELLOW}${question}${NC} ${WHITE}[Y/n]${NC} "
    else
        echo -ne "${YELLOW}${question}${NC} ${WHITE}[y/N]${NC} "
    fi
    
    # Force read to wait for input
    read -r response
    
    # Use default if empty response
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

pause_for_user() {
    echo -e "\n${CYAN}$(t 'prompt.press_enter')${NC}"
    read -r
}
