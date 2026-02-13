#!/bin/bash
# ============================================================================
# SSL/TLS CIPHER SUITE SECURITY AUDIT SCRIPT
# ============================================================================
# This script checks your mail server for weak or deprecated cipher suites
# and provides recommendations for strengthening security.
#
# Usage: sudo ./check-ssl-ciphers.sh
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}" 
   exit 1
fi

echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo -e "${BOLD}${BLUE}           SSL/TLS CIPHER SUITE SECURITY AUDIT${NC}"
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo ""

# ============================================================================
# WEAK/DEPRECATED CIPHERS TO CHECK FOR
# ============================================================================

WEAK_CIPHERS=(
    "NULL"      "No encryption"
    "aNULL"     "Anonymous (no authentication)"
    "eNULL"     "No encryption"
    "EXPORT"    "Export-grade (weak by design)"
    "DES"       "DES encryption (56-bit, broken)"
    "3DES"      "Triple DES (deprecated, slow)"
    "MD5"       "MD5 hash (broken)"
    "RC2"       "RC2 cipher (weak)"
    "RC4"       "RC4 stream cipher (broken)"
    "PSK"       "Pre-shared key (often misconfigured)"
    "DSS"       "DSS/DSA keys (deprecated)"
    "SEED"      "SEED cipher (outdated)"
    "IDEA"      "IDEA cipher (outdated)"
    "CAMELLIA"  "Camellia cipher (less scrutinized)"
    "CBC"       "CBC mode (vulnerable to BEAST/Lucky13)"
    "SSLv2"     "SSL 2.0 protocol (broken)"
    "SSLv3"     "SSL 3.0 protocol (POODLE vulnerability)"
    "TLSv1.0"   "TLS 1.0 protocol (deprecated)"
    "TLSv1.1"   "TLS 1.1 protocol (deprecated)"
)

# Mozilla Modern recommended cipher suite
MOZILLA_MODERN="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"

# ============================================================================
# FUNCTIONS
# ============================================================================

check_file_exists() {
    if [[ ! -f "$1" ]]; then
        echo -e "${YELLOW}⚠  File not found: $1${NC}"
        return 1
    fi
    return 0
}

check_service_running() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        return 0
    fi
    return 1
}

test_cipher_support() {
    local service=$1
    local port=$2
    local cipher=$3
    
    timeout 5 openssl s_client -connect localhost:$port -cipher "$cipher" </dev/null &>/dev/null
    return $?
}

# ============================================================================
# CHECK POSTFIX CONFIGURATION
# ============================================================================

echo -e "${BOLD}${CYAN}[1/5] Checking Postfix Configuration...${NC}"
echo ""

POSTFIX_CONF="/etc/postfix/main.cf"
if check_file_exists "$POSTFIX_CONF"; then
    echo -e "${GREEN}✓${NC} Postfix configuration found"
    
    # Check TLS protocols
    echo -e "\n${BOLD}TLS Protocols:${NC}"
    protocols=$(grep -E "^smtpd_tls_protocols" "$POSTFIX_CONF" | cut -d'=' -f2-)
    if [[ -n "$protocols" ]]; then
        echo "  $protocols"
        if echo "$protocols" | grep -qiE "SSLv2|SSLv3|TLSv1\.0|TLSv1\.1"; then
            echo -e "  ${RED}✗ VULNERABLE: Weak protocols enabled${NC}"
        else
            echo -e "  ${GREEN}✓ Good: Only modern protocols enabled${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  Not explicitly configured${NC}"
    fi
    
    # Check ciphers
    echo -e "\n${BOLD}Cipher Configuration:${NC}"
    ciphers=$(grep -E "^smtpd_tls_ciphers|^smtpd_tls_mandatory_ciphers" "$POSTFIX_CONF")
    if [[ -n "$ciphers" ]]; then
        echo "$ciphers"
        
        # Check for excluded ciphers
        excluded=$(grep "^smtpd_tls_exclude_ciphers" "$POSTFIX_CONF")
        if [[ -n "$excluded" ]]; then
            echo -e "${GREEN}✓ Explicit cipher exclusions found:${NC}"
            echo "$excluded" | sed 's/^/  /'
        else
            echo -e "${YELLOW}⚠  Recommendation: Add explicit cipher exclusions${NC}"
        fi
    else
        echo -e "${YELLOW}⚠  Cipher configuration not found${NC}"
    fi
    
    # Check DH parameters
    echo -e "\n${BOLD}DH Parameters:${NC}"
    dh_bits=$(grep "^smtpd_tls_dh_min_bits" "$POSTFIX_CONF" | cut -d'=' -f2- | tr -d ' ')
    if [[ -n "$dh_bits" ]]; then
        if [[ "$dh_bits" -ge 2048 ]]; then
            echo -e "  ${GREEN}✓ DH minimum bits: $dh_bits (secure)${NC}"
        else
            echo -e "  ${RED}✗ DH minimum bits: $dh_bits (too weak, use 2048+)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  DH parameters not configured${NC}"
    fi
else
    echo -e "${YELLOW}⚠  Postfix not configured${NC}"
fi

# ============================================================================
# CHECK DOVECOT CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[2/5] Checking Dovecot Configuration...${NC}"
echo ""

DOVECOT_CONF="/etc/dovecot/dovecot.conf"
if check_file_exists "$DOVECOT_CONF"; then
    echo -e "${GREEN}✓${NC} Dovecot configuration found"
    
    # Check SSL requirement
    echo -e "\n${BOLD}SSL Requirement:${NC}"
    ssl_req=$(grep "^ssl" "$DOVECOT_CONF" | head -1)
    if echo "$ssl_req" | grep -q "required"; then
        echo -e "  ${GREEN}✓ SSL is required${NC}"
    else
        echo -e "  ${YELLOW}⚠  SSL may not be required: $ssl_req${NC}"
    fi
    
    # Check minimum protocol
    echo -e "\n${BOLD}Minimum SSL/TLS Protocol:${NC}"
    min_proto=$(grep "^ssl_min_protocol" "$DOVECOT_CONF" | cut -d'=' -f2- | tr -d ' ')
    if [[ -n "$min_proto" ]]; then
        if [[ "$min_proto" == "TLSv1.2" || "$min_proto" == "TLSv1.3" ]]; then
            echo -e "  ${GREEN}✓ Minimum protocol: $min_proto (secure)${NC}"
        else
            echo -e "  ${RED}✗ Minimum protocol: $min_proto (upgrade to TLSv1.2+)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  Minimum protocol not set${NC}"
    fi
    
    # Check cipher list
    echo -e "\n${BOLD}Cipher List:${NC}"
    cipher_list=$(grep "^ssl_cipher_list" "$DOVECOT_CONF" | cut -d'=' -f2-)
    if [[ -n "$cipher_list" ]]; then
        echo "  $cipher_list"
        
        # Check for weak ciphers
        weak_found=0
        for ((i=0; i<${#WEAK_CIPHERS[@]}; i+=2)); do
            cipher="${WEAK_CIPHERS[i]}"
            if echo "$cipher_list" | grep -qi "$cipher"; then
                echo -e "  ${RED}✗ VULNERABLE: Contains $cipher${NC}"
                weak_found=1
            fi
        done
        
        if [[ $weak_found -eq 0 ]]; then
            echo -e "  ${GREEN}✓ No obvious weak ciphers detected${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  Cipher list not configured${NC}"
    fi
else
    echo -e "${YELLOW}⚠  Dovecot not configured${NC}"
fi

# ============================================================================
# CHECK NGINX CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[3/5] Checking Nginx Configuration...${NC}"
echo ""

NGINX_CONF_DIR="/etc/nginx/sites-available"
if [[ -d "$NGINX_CONF_DIR" ]]; then
    echo -e "${GREEN}✓${NC} Nginx configuration directory found"
    
    for conf in "$NGINX_CONF_DIR"/*; do
        if [[ -f "$conf" ]]; then
            echo -e "\n${BOLD}Checking: $(basename $conf)${NC}"
            
            # Check protocols
            protocols=$(grep "ssl_protocols" "$conf" | head -1)
            if [[ -n "$protocols" ]]; then
                echo "  Protocols: $protocols"
                if echo "$protocols" | grep -qiE "SSLv2|SSLv3|TLSv1\.0|TLSv1\.1"; then
                    echo -e "    ${RED}✗ VULNERABLE: Weak protocols enabled${NC}"
                else
                    echo -e "    ${GREEN}✓ Good: Only modern protocols${NC}"
                fi
            fi
            
            # Check ciphers
            ciphers=$(grep "ssl_ciphers" "$conf" | head -1)
            if [[ -n "$ciphers" ]]; then
                # Check for common weak indicators
                if echo "$ciphers" | grep -qiE "HIGH:!aNULL:!MD5|ALL|DEFAULT"; then
                    echo -e "    ${YELLOW}⚠  Generic cipher string detected${NC}"
                    echo -e "    ${YELLOW}   Recommendation: Use explicit Mozilla Modern cipher list${NC}"
                else
                    echo -e "    ${GREEN}✓ Explicit cipher list configured${NC}"
                fi
            fi
            
            # Check for HSTS
            if grep -q "Strict-Transport-Security" "$conf"; then
                echo -e "    ${GREEN}✓ HSTS enabled${NC}"
            else
                echo -e "    ${YELLOW}⚠  HSTS not configured${NC}"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠  Nginx not configured or using different directory${NC}"
fi

# ============================================================================
# CHECK APACHE CONFIGURATION
# ============================================================================

echo -e "\n${BOLD}${CYAN}[4/5] Checking Apache Configuration...${NC}"
echo ""

APACHE_CONF_DIRS=("/etc/apache2/sites-available" "/etc/httpd/conf.d")
apache_found=0

for conf_dir in "${APACHE_CONF_DIRS[@]}"; do
    if [[ -d "$conf_dir" ]]; then
        apache_found=1
        echo -e "${GREEN}✓${NC} Apache configuration directory found: $conf_dir"
        
        for conf in "$conf_dir"/*.conf; do
            if [[ -f "$conf" ]] && grep -q "SSLEngine" "$conf"; then
                echo -e "\n${BOLD}Checking: $(basename $conf)${NC}"
                
                # Check protocols
                protocols=$(grep "SSLProtocol" "$conf" | head -1)
                if [[ -n "$protocols" ]]; then
                    echo "  Protocols: $protocols"
                    if echo "$protocols" | grep -qiE "\-SSLv2|\-SSLv3|\-TLSv1\.0|\-TLSv1\.1"; then
                        echo -e "    ${GREEN}✓ Weak protocols disabled${NC}"
                    else
                        echo -e "    ${YELLOW}⚠  Check if weak protocols are disabled${NC}"
                    fi
                fi
                
                # Check ciphers
                ciphers=$(grep "SSLCipherSuite" "$conf" | head -1)
                if [[ -n "$ciphers" ]]; then
                    if echo "$ciphers" | grep -qiE "HIGH:!aNULL:!MD5|ALL"; then
                        echo -e "    ${YELLOW}⚠  Generic cipher string detected${NC}"
                    else
                        echo -e "    ${GREEN}✓ Explicit cipher list configured${NC}"
                    fi
                fi
                
                # Check for HSTS
                if grep -q "Strict-Transport-Security" "$conf"; then
                    echo -e "    ${GREEN}✓ HSTS enabled${NC}"
                else
                    echo -e "    ${YELLOW}⚠  HSTS not configured${NC}"
                fi
            fi
        done
    fi
done

if [[ $apache_found -eq 0 ]]; then
    echo -e "${YELLOW}⚠  Apache not configured${NC}"
fi

# ============================================================================
# LIVE CONNECTION TESTS
# ============================================================================

echo -e "\n${BOLD}${CYAN}[5/5] Testing Live Connections...${NC}"
echo ""

# Test SMTP
if check_service_running "postfix"; then
    echo -e "${BOLD}Testing SMTP (port 587):${NC}"
    if timeout 2 openssl s_client -connect localhost:587 -starttls smtp </dev/null &>/dev/null; then
        protocol=$(echo | timeout 2 openssl s_client -connect localhost:587 -starttls smtp 2>/dev/null | grep "Protocol" | cut -d':' -f2)
        cipher=$(echo | timeout 2 openssl s_client -connect localhost:587 -starttls smtp 2>/dev/null | grep "Cipher" | cut -d':' -f2)
        echo -e "  Protocol:$protocol"
        echo -e "  Cipher:$cipher"
        
        # Test weak ciphers
        if test_cipher_support "smtp" 587 "DES-CBC3-SHA"; then
            echo -e "  ${RED}✗ VULNERABLE: 3DES cipher accepted${NC}"
        else
            echo -e "  ${GREEN}✓ 3DES cipher rejected${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠  Could not connect${NC}"
    fi
else
    echo -e "${YELLOW}⚠  Postfix not running${NC}"
fi

# Test IMAP
echo ""
if check_service_running "dovecot"; then
    echo -e "${BOLD}Testing IMAP (port 993):${NC}"
    if timeout 2 openssl s_client -connect localhost:993 </dev/null &>/dev/null; then
        protocol=$(echo | timeout 2 openssl s_client -connect localhost:993 2>/dev/null | grep "Protocol" | cut -d':' -f2)
        cipher=$(echo | timeout 2 openssl s_client -connect localhost:993 2>/dev/null | grep "Cipher" | cut -d':' -f2)
        echo -e "  Protocol:$protocol"
        echo -e "  Cipher:$cipher"
    else
        echo -e "  ${YELLOW}⚠  Could not connect${NC}"
    fi
else
    echo -e "${YELLOW}⚠  Dovecot not running${NC}"
fi

# Test HTTPS
echo ""
https_found=0
if check_service_running "nginx" || check_service_running "apache2" || check_service_running "httpd"; then
    echo -e "${BOLD}Testing HTTPS (port 443):${NC}"
    if timeout 2 openssl s_client -connect localhost:443 </dev/null &>/dev/null; then
        https_found=1
        protocol=$(echo | timeout 2 openssl s_client -connect localhost:443 2>/dev/null | grep "Protocol" | cut -d':' -f2)
        cipher=$(echo | timeout 2 openssl s_client -connect localhost:443 2>/dev/null | grep "Cipher" | cut -d':' -f2)
        echo -e "  Protocol:$protocol"
        echo -e "  Cipher:$cipher"
    else
        echo -e "  ${YELLOW}⚠  Could not connect (no HTTPS configured?)${NC}"
    fi
fi

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

echo ""
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo -e "${BOLD}${BLUE}                         RECOMMENDATIONS${NC}"
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo ""

echo -e "${BOLD}${GREEN}✓ RECOMMENDED CONFIGURATION (Mozilla Modern):${NC}"
echo ""

echo -e "${BOLD}Postfix (/etc/postfix/main.cf):${NC}"
cat << 'EOF'
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtpd_tls_ciphers = high
smtpd_tls_mandatory_ciphers = high
smtpd_tls_exclude_ciphers = aNULL, eNULL, EXPORT, DES, 3DES, MD5, PSK, RC4, DSS, SEED, IDEA, CAMELLIA, CBC
smtpd_tls_prefer_server_ciphers = yes
smtpd_tls_dh_min_bits = 2048
EOF

echo ""
echo -e "${BOLD}Dovecot (/etc/dovecot/dovecot.conf):${NC}"
echo "ssl_min_protocol = TLSv1.2"
echo "ssl_cipher_list = $MOZILLA_MODERN"
echo "ssl_prefer_server_ciphers = yes"

echo ""
echo -e "${BOLD}Nginx:${NC}"
echo "ssl_protocols TLSv1.2 TLSv1.3;"
echo "ssl_ciphers '$MOZILLA_MODERN';"
echo "ssl_prefer_server_ciphers on;"
echo "ssl_session_tickets off;"

echo ""
echo -e "${BOLD}Apache:${NC}"
echo "SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1"
echo "SSLCipherSuite $MOZILLA_MODERN"
echo "SSLHonorCipherOrder on"
echo "SSLCompression off"
echo "SSLSessionTickets off"

echo ""
echo -e "${BOLD}${YELLOW}⚠  SECURITY TIPS:${NC}"
echo "  1. Run: sudo ./update-ssl-config.sh (to auto-update configurations)"
echo "  2. Test your server: https://www.ssllabs.com/ssltest/"
echo "  3. Keep software updated: apt-get update && apt-get upgrade"
echo "  4. Enable HSTS headers in web server configs"
echo "  5. Generate strong DH parameters: openssl dhparam -out /etc/ssl/dhparam.pem 4096"
echo "  6. Restart services after config changes"

echo ""
echo -e "${BOLD}${BLUE}============================================================================${NC}"
echo -e "${BOLD}${GREEN}Audit Complete!${NC}"
echo -e "${BOLD}${BLUE}============================================================================${NC}"
