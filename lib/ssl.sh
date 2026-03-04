#!/usr/bin/env bash

# ============================================================================
# SSL/TLS Certificates Management Library
# ============================================================================
# This library provides functions for obtaining and managing Let's Encrypt
# SSL/TLS certificates for the mail server and webmail.
# ============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui.sh"
source "${SCRIPT_DIR}/packages.sh"

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
        log_step "Obtaining certificate for $MAIL_HOSTNAME..."
        
        # Stop services that might be using port 80
        systemctl stop postfix dovecot 2>/dev/null || true
        if [ "$WEB_SERVER" = "nginx" ]; then
            systemctl stop nginx 2>/dev/null || true
        elif [ "$WEB_SERVER" = "apache" ]; then
            systemctl stop apache2 httpd 2>/dev/null || true
        fi
        
        # Get certificate using standalone method
        certbot certonly --standalone \
            -d "$MAIL_HOSTNAME" \
            --non-interactive \
            --agree-tos \
            --email "$ADMIN_EMAIL" \
            --keep-until-expiring
        
        if [ $? -eq 0 ]; then
            log_success "Certificate obtained for $MAIL_HOSTNAME"
            
            # Update Postfix to use new certificates
            sed -i "s|smtpd_tls_cert_file.*|smtpd_tls_cert_file = /etc/letsencrypt/live/$MAIL_HOSTNAME/fullchain.pem|" "$POSTFIX_DIR/main.cf"
            sed -i "s|smtpd_tls_key_file.*|smtpd_tls_key_file = /etc/letsencrypt/live/$MAIL_HOSTNAME/privkey.pem|" "$POSTFIX_DIR/main.cf"
            
            # Update Dovecot to use new certificates
            sed -i "s|ssl_cert.*|ssl_cert = </etc/letsencrypt/live/$MAIL_HOSTNAME/fullchain.pem|" "$DOVECOT_DIR/dovecot.conf"
            sed -i "s|ssl_key.*|ssl_key = </etc/letsencrypt/live/$MAIL_HOSTNAME/privkey.pem|" "$DOVECOT_DIR/dovecot.conf"
        else
            log_error "Failed to obtain certificate for $MAIL_HOSTNAME"
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
        echo "  certbot certonly --standalone -d $MAIL_HOSTNAME -d ${MAIL_DOMAINS[0]}"
        if [ "$WEBMAIL_CHOICE" != "none" ]; then
            echo "  certbot certonly --standalone -d mail.${PRIMARY_DOMAIN}"
        fi
    fi
}
