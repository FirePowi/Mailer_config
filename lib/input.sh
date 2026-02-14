#!/usr/bin/env bash
#
# User Input Collection Library
# Handles interactive user input for configuration
#

# Source UI library for colors and formatting
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ui.sh"

collect_basic_info() {
    print_section "Basic Configuration"
    
    echo -e "${WHITE}Let's configure your mail server. I'll ask you a few questions.${NC}"
    echo ""
    
    # Primary domain
    while true; do
        echo -ne "${YELLOW}Enter your primary mail domain (e.g., example.com):${NC} "
        read -r PRIMARY_DOMAIN
        PRIMARY_DOMAIN="${PRIMARY_DOMAIN:-}"
        # Trim whitespace
        PRIMARY_DOMAIN=$(echo "$PRIMARY_DOMAIN" | xargs)
        # Validate: alphanumeric with dots and hyphens, at least one dot, TLD with 2+ chars
        if [[ "$PRIMARY_DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
            DOMAINS+=("$PRIMARY_DOMAIN")
            break
        else
            log_error "Invalid domain format. Please try again."
            log_info "Examples: example.com, mail.example.com, my-domain.org"
        fi
    done
    
    # Hostname
    echo -ne "${YELLOW}Enter the mail server hostname [mail.$PRIMARY_DOMAIN]:${NC} "
    read -r hostname_input
    hostname_input="${hostname_input:-}"
    HOSTNAME="${hostname_input:-mail.$PRIMARY_DOMAIN}"
    
    # Admin email
    echo -ne "${YELLOW}Enter admin email address [admin@$PRIMARY_DOMAIN]:${NC} "
    read -r email_input
    email_input="${email_input:-}"
    ADMIN_EMAIL="${email_input:-admin@$PRIMARY_DOMAIN}"
    
    # Additional domains
    echo ""
    echo -ne "${YELLOW}Do you want to add additional domains? [y/N]:${NC} "
    read -r add_domains
    add_domains="${add_domains:-}"
    
    if [[ "$add_domains" =~ ^[Yy]$ ]]; then
        while true; do
            echo -ne "${YELLOW}Enter additional domain (or press Enter to finish):${NC} "
            read -r domain
            domain="${domain:-}"
            # Trim whitespace
            domain=$(echo "$domain" | xargs)
            if [[ -z "$domain" ]]; then
                break
            elif [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
                DOMAINS+=("$domain")
                log_success "Added domain: $domain"
            else
                log_error "Invalid domain format"
                log_info "Examples: example.com, mail.example.com, my-domain.org"
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
    echo -ne "${YELLOW}Install SpamAssassin? (spam filtering) [Y/n]:${NC} "
    read -r spamassassin_choice
    spamassassin_choice="${spamassassin_choice:-y}"
    if [[ "$spamassassin_choice" =~ ^[Yy]$ ]]; then
        ENABLE_SPAMASSASSIN=true
    fi
    
    # ClamAV
    echo -ne "${YELLOW}Install ClamAV? (antivirus scanning) [y/N]:${NC} "
    read -r clamav_choice
    clamav_choice="${clamav_choice:-n}"
    if [[ "$clamav_choice" =~ ^[Yy]$ ]]; then
        ENABLE_CLAMAV=true
    fi
    
    # Rspamd (alternative to SpamAssassin)
    if ! $ENABLE_SPAMASSASSIN; then
        echo -ne "${YELLOW}Install Rspamd? (modern spam filtering alternative) [y/N]:${NC} "
        read -r rspamd_choice
        rspamd_choice="${rspamd_choice:-n}"
        if [[ "$rspamd_choice" =~ ^[Yy]$ ]]; then
            ENABLE_RSPAMD=true
        fi
    fi
    
    # OpenDKIM
    echo ""
    echo -ne "${YELLOW}Install OpenDKIM? (email authentication) [Y/n]:${NC} "
    read -r dkim_choice
    dkim_choice="${dkim_choice:-y}"
    if [[ "$dkim_choice" =~ ^[Yy]$ ]]; then
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
        echo -ne "${YELLOW}Select webmail client [1-$option_num] [1]:${NC} "
        read -r webmail_selection
        webmail_selection="${webmail_selection:-1}"
        if [[ "$webmail_selection" =~ ^[0-9]+$ ]] && [[ "$webmail_selection" -ge 1 && "$webmail_selection" -le "$option_num" ]]; then
            WEBMAIL_CHOICE="${available_options[$((webmail_selection-1))]}"
            if [[ "$WEBMAIL_CHOICE" == "none" ]]; then
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
