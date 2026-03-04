#!/usr/bin/env bash

# ============================================================================
# Service Management Library
# ============================================================================
# This library provides functions for starting, enabling, and managing
# mail server services and displaying final installation instructions.
# ============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui.sh"

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
${CYAN}Hostname:${NC}           $MAIL_HOSTNAME
${CYAN}Admin Email:${NC}        $ADMIN_EMAIL
${CYAN}Total Domains:${NC}      ${#MAIL_DOMAINS[@]}

${CYAN}Domains configured:${NC}
EOF

    for domain in "${MAIL_DOMAINS[@]}"; do
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
${WHITE}https://$MAIL_HOSTNAME/postfixadmin${NC}
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
${CYAN}SOGo Webmail/Groupware:${NC}
${WHITE}https://mail.$PRIMARY_DOMAIN${NC}

${YELLOW}Features:${NC}
• Webmail interface
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

${CYAN}1.${NC} Configure PostfixAdmin:
   Visit https://$MAIL_HOSTNAME/postfixadmin
   Complete the setup wizard with the provided password

${CYAN}2.${NC} Create email accounts:
   Use PostfixAdmin web interface to create mailboxes

${CYAN}3.${NC} Test your mail server:
   Send a test email to one of your newly created accounts

${CYAN}4.${NC} Configure email client:
   Use the following settings:
   
   ${BOLD}Incoming Mail (IMAP):${NC}
   Server: $MAIL_HOSTNAME
   Port: 993
   Security: SSL/TLS
   
   ${BOLD}Outgoing Mail (SMTP):${NC}
   Server: $MAIL_HOSTNAME
   Port: 587
   Security: STARTTLS

${CYAN}5.${NC} Monitor logs for issues:
   • Postfix: tail -f /var/log/mail.log
   • Dovecot: tail -f /var/log/dovecot.log

${BOLD}${WHITE}IMPORTANT SECURITY NOTES${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${YELLOW}⚠${NC}  Keep your database passwords secure
${YELLOW}⚠${NC}  Regularly update your system and mail server software
${YELLOW}⚠${NC}  Monitor mail logs for suspicious activity
${YELLOW}⚠${NC}  Backup your mail data and configuration regularly

${GREEN}Thank you for using this mail server installer!${NC}

EOF
}
