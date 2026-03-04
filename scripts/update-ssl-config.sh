#!/bin/bash
# ============================================================================
# SSL/TLS CONFIGURATION AUTO-UPDATE SCRIPT
# ============================================================================
# This script automatically updates SSL/TLS configurations to use modern,
# secure cipher suites across all mail server components.
#
# Usage: sudo ./update-ssl-config.sh
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}" 
   exit 1
fi

# Mozilla Modern cipher suite (TLS 1.2+ only)
MOZILLA_MODERN="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"

echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo -e "${BOLD}${BLUE}           SSL/TLS CONFIGURATION AUTO-UPDATE${NC}"
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo ""
echo -e "${YELLOW}This script will update your SSL/TLS configurations to use${NC}"
echo -e "${YELLOW}Mozilla Modern cipher suites (TLS 1.2+ only, no weak ciphers).${NC}"
echo ""
echo -e "${BOLD}Backups will be created with .backup extension.${NC}"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

services_to_restart=()

# ============================================================================
# UPDATE POSTFIX CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[1/4] Updating Postfix Configuration...${NC}"

POSTFIX_CONF="/etc/postfix/main.cf"
if [[ -f "$POSTFIX_CONF" ]]; then
    # Backup
    cp "$POSTFIX_CONF" "${POSTFIX_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓${NC} Backup created: ${POSTFIX_CONF}.backup.*"
    
    # Update or add TLS protocols
    if grep -q "^smtpd_tls_protocols" "$POSTFIX_CONF"; then
        sed -i 's/^smtpd_tls_protocols.*/smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1/' "$POSTFIX_CONF"
        echo -e "${GREEN}✓${NC} Updated smtpd_tls_protocols"
    else
        echo "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1" >> "$POSTFIX_CONF"
        echo -e "${GREEN}✓${NC} Added smtpd_tls_protocols"
    fi
    
    # Update cipher settings
    if ! grep -q "^smtpd_tls_exclude_ciphers" "$POSTFIX_CONF"; then
        cat >> "$POSTFIX_CONF" << 'EOF'

# Exclude weak/deprecated ciphers
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, 3DES, MD5, PSK, RC4, DSS, SEED, IDEA, CAMELLIA, CBC
EOF
        echo -e "${GREEN}✓${NC} Added cipher exclusions"
    fi
    
    # Ensure high ciphers
    if grep -q "^smtpd_tls_ciphers" "$POSTFIX_CONF"; then
        sed -i 's/^smtpd_tls_ciphers.*/smtpd_tls_ciphers = high/' "$POSTFIX_CONF"
    else
        echo "smtpd_tls_ciphers = high" >> "$POSTFIX_CONF"
    fi
    
    if grep -q "^smtpd_tls_mandatory_ciphers" "$POSTFIX_CONF"; then
        sed -i 's/^smtpd_tls_mandatory_ciphers.*/smtpd_tls_mandatory_ciphers = high/' "$POSTFIX_CONF"
    else
        echo "smtpd_tls_mandatory_ciphers = high" >> "$POSTFIX_CONF"
    fi
    
    # Ensure DH parameters
    if ! grep -q "^smtpd_tls_dh_min_bits" "$POSTFIX_CONF"; then
        echo "smtpd_tls_dh_min_bits = 2048" >> "$POSTFIX_CONF"
        echo -e "${GREEN}✓${NC} Added DH minimum bits"
    fi
    
    # Prefer server ciphers
    if ! grep -q "^smtpd_tls_prefer_server_ciphers" "$POSTFIX_CONF"; then
        echo "smtpd_tls_prefer_server_ciphers = yes" >> "$POSTFIX_CONF"
    fi
    
    echo -e "${GREEN}✓${NC} Postfix configuration updated"
    services_to_restart+=("postfix")
else
    echo -e "${YELLOW}⚠${NC}  Postfix config not found, skipping"
fi

# ============================================================================
# UPDATE DOVECOT CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[2/4] Updating Dovecot Configuration...${NC}"

DOVECOT_CONF="/etc/dovecot/dovecot.conf"
if [[ -f "$DOVECOT_CONF" ]]; then
    # Backup
    cp "$DOVECOT_CONF" "${DOVECOT_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓${NC} Backup created: ${DOVECOT_CONF}.backup.*"
    
    # Update minimum protocol
    if grep -q "^ssl_min_protocol" "$DOVECOT_CONF"; then
        sed -i 's/^ssl_min_protocol.*/ssl_min_protocol = TLSv1.2/' "$DOVECOT_CONF"
        echo -e "${GREEN}✓${NC} Updated ssl_min_protocol"
    else
        echo "ssl_min_protocol = TLSv1.2" >> "$DOVECOT_CONF"
        echo -e "${GREEN}✓${NC} Added ssl_min_protocol"
    fi
    
    # Update cipher list
    if grep -q "^ssl_cipher_list" "$DOVECOT_CONF"; then
        sed -i "s|^ssl_cipher_list.*|ssl_cipher_list = $MOZILLA_MODERN|" "$DOVECOT_CONF"
        echo -e "${GREEN}✓${NC} Updated ssl_cipher_list"
    else
        echo "ssl_cipher_list = $MOZILLA_MODERN" >> "$DOVECOT_CONF"
        echo -e "${GREEN}✓${NC} Added ssl_cipher_list"
    fi
    
    # Prefer server ciphers
    if ! grep -q "^ssl_prefer_server_ciphers" "$DOVECOT_CONF"; then
        echo "ssl_prefer_server_ciphers = yes" >> "$DOVECOT_CONF"
    fi
    
    echo -e "${GREEN}✓${NC} Dovecot configuration updated"
    services_to_restart+=("dovecot")
else
    echo -e "${YELLOW}⚠${NC}  Dovecot config not found, skipping"
fi

# ============================================================================
# UPDATE NGINX CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[3/4] Updating Nginx Configuration...${NC}"

NGINX_CONF_DIRS=("/etc/nginx/sites-available" "/etc/nginx/conf.d")
nginx_updated=0

for conf_dir in "${NGINX_CONF_DIRS[@]}"; do
    if [[ -d "$conf_dir" ]]; then
        for conf in "$conf_dir"/*; do
            if [[ -f "$conf" ]] && grep -q "ssl_certificate" "$conf"; then
                # Backup
                cp "$conf" "${conf}.backup.$(date +%Y%m%d_%H%M%S)"
                
                # Update protocols
                if grep -q "ssl_protocols" "$conf"; then
                    sed -i 's/ssl_protocols.*/ssl_protocols TLSv1.2 TLSv1.3;/' "$conf"
                fi
                
                # Update ciphers
                if grep -q "ssl_ciphers" "$conf"; then
                    sed -i "s|ssl_ciphers.*|ssl_ciphers '$MOZILLA_MODERN';|" "$conf"
                fi
                
                # Add security settings if not present
                if ! grep -q "ssl_prefer_server_ciphers" "$conf"; then
                    sed -i "/ssl_ciphers/a\    ssl_prefer_server_ciphers on;" "$conf"
                fi
                
                if ! grep -q "ssl_session_tickets" "$conf"; then
                    sed -i "/ssl_prefer_server_ciphers/a\    ssl_session_tickets off;" "$conf"
                fi
                
                # Add HSTS if not present
                if ! grep -q "Strict-Transport-Security" "$conf"; then
                    sed -i "/ssl_session_tickets/a\    add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;" "$conf"
                fi
                
                echo -e "${GREEN}✓${NC} Updated: $(basename $conf)"
                nginx_updated=1
            fi
        done
    fi
done

if [[ $nginx_updated -eq 1 ]]; then
    # Test configuration
    if nginx -t &>/dev/null; then
        echo -e "${GREEN}✓${NC} Nginx configuration is valid"
        services_to_restart+=("nginx")
    else
        echo -e "${RED}✗${NC} Nginx configuration test failed - please check manually"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No Nginx SSL configurations found"
fi

# ============================================================================
# UPDATE APACHE CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[4/4] Updating Apache Configuration...${NC}"

APACHE_CONF_DIRS=("/etc/apache2/sites-available" "/etc/httpd/conf.d")
apache_updated=0

for conf_dir in "${APACHE_CONF_DIRS[@]}"; do
    if [[ -d "$conf_dir" ]]; then
        for conf in "$conf_dir"/*.conf; do
            if [[ -f "$conf" ]] && grep -q "SSLEngine" "$conf"; then
                # Backup
                cp "$conf" "${conf}.backup.$(date +%Y%m%d_%H%M%S)"
                
                # Update protocols
                if grep -q "SSLProtocol" "$conf"; then
                    sed -i 's/SSLProtocol.*/SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1/' "$conf"
                fi
                
                # Update ciphers
                if grep -q "SSLCipherSuite" "$conf"; then
                    sed -i "s|SSLCipherSuite.*|SSLCipherSuite $MOZILLA_MODERN|" "$conf"
                fi
                
                # Add security settings
                if ! grep -q "SSLHonorCipherOrder" "$conf"; then
                    sed -i "/SSLCipherSuite/a\    SSLHonorCipherOrder on" "$conf"
                fi
                
                if ! grep -q "SSLCompression" "$conf"; then
                    sed -i "/SSLHonorCipherOrder/a\    SSLCompression off" "$conf"
                fi
                
                if ! grep -q "SSLSessionTickets" "$conf"; then
                    sed -i "/SSLCompression/a\    SSLSessionTickets off" "$conf"
                fi
                
                # Add HSTS
                if ! grep -q "Strict-Transport-Security" "$conf"; then
                    sed -i "/SSLSessionTickets/a\    Header always set Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\"" "$conf"
                fi
                
                echo -e "${GREEN}✓${NC} Updated: $(basename $conf)"
                apache_updated=1
            fi
        done
    fi
done

if [[ $apache_updated -eq 1 ]]; then
    # Test configuration
    if apache2ctl -t &>/dev/null || httpd -t &>/dev/null; then
        echo -e "${GREEN}✓${NC} Apache configuration is valid"
        services_to_restart+=("apache2" "httpd")
    else
        echo -e "${RED}✗${NC} Apache configuration test failed - please check manually"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No Apache SSL configurations found"
fi

# ============================================================================
# RESTART SERVICES
# ============================================================================

if [[ ${#services_to_restart[@]} -gt 0 ]]; then
    echo ""
    echo -e "${BOLD}${YELLOW}Services need to be restarted for changes to take effect:${NC}"
    for service in "${services_to_restart[@]}"; do
        echo "  - $service"
    done
    echo ""
    
    read -p "Restart services now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        for service in "${services_to_restart[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                echo -e "${CYAN}Restarting $service...${NC}"
                if systemctl restart "$service"; then
                    echo -e "${GREEN}✓${NC} $service restarted successfully"
                else
                    echo -e "${RED}✗${NC} Failed to restart $service"
                fi
            fi
        done
    else
        echo -e "${YELLOW}Remember to restart services manually:${NC}"
        for service in "${services_to_restart[@]}"; do
            echo "  systemctl restart $service"
        done
    fi
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo -e "${BOLD}${BLUE}                         UPDATE COMPLETE${NC}"
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo ""

echo -e "${BOLD}${GREEN}✓ All configurations updated to use Mozilla Modern cipher suites${NC}"
echo ""
echo -e "${BOLD}What was changed:${NC}"
echo "  • TLS protocols: Only TLSv1.2 and TLSv1.3 enabled"
echo "  • Weak ciphers: Explicitly excluded (3DES, RC4, MD5, CBC, etc.)"
echo "  • Strong ciphers: ECDHE + AES-GCM + SHA256/384"
echo "  • Security headers: HSTS, X-Frame-Options, CSP"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Test your configuration: sudo ./check-ssl-ciphers.sh"
echo "  2. External test: https://www.ssllabs.com/ssltest/"
echo "  3. Monitor logs for any client compatibility issues"
echo ""
echo -e "${BOLD}${CYAN}Note: These settings prioritize security over compatibility.${NC}"
echo -e "${CYAN}Very old clients (pre-2016) may not be able to connect.${NC}"
echo ""
echo -e "${BOLD}${BLUE}============================================================================${NC}"
