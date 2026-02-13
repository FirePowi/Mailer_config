#!/usr/bin/env bash
#
# Mail Server Testing Suite
# Automated step-by-step testing of mail server configuration
#
# Usage: sudo ./test-server.sh [options]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0
CRITICAL_FAILED=false

# Configuration
VERBOSE=false
QUIET=false
REPORT_FILE=""
TEST_FILTER=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
    if [[ "$QUIET" == false ]]; then
        echo -e "${BOLD}${CYAN}"
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                       ║"
        echo "║              Mail Server Testing Suite                               ║"
        echo "║                                                                       ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
}

print_section() {
    if [[ "$QUIET" == false ]]; then
        echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}\n"
    fi
}

log_pass() {
    ((TESTS_PASSED++))
    if [[ "$QUIET" == false ]]; then
        echo -e "${GREEN}[✓]${NC} $*"
    fi
    [[ -n "$REPORT_FILE" ]] && echo "[PASS] $*" >> "$REPORT_FILE"
}

log_fail() {
    ((TESTS_FAILED++))
    if [[ "$QUIET" == false ]]; then
        echo -e "${RED}[✗]${NC} $*"
    fi
    [[ -n "$REPORT_FILE" ]] && echo "[FAIL] $*" >> "$REPORT_FILE"
}

log_warn() {
    ((TESTS_WARNING++))
    if [[ "$QUIET" == false ]]; then
        echo -e "${YELLOW}[!]${NC} $*"
    fi
    [[ -n "$REPORT_FILE" ]] && echo "[WARN] $*" >> "$REPORT_FILE"
}

log_info() {
    if [[ "$QUIET" == false ]] || [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}[i]${NC} $*"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${WHITE}    $*${NC}"
    fi
}

# ============================================================================
# TEST FUNCTIONS
# ============================================================================

test_service() {
    local service_name="$1"
    local display_name="${2:-$service_name}"
    
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        log_pass "$display_name is running"
        log_verbose "Status: $(systemctl is-active "$service_name")"
        return 0
    else
        log_fail "$display_name is not running"
        log_verbose "Try: systemctl start $service_name"
        CRITICAL_FAILED=true
        return 1
    fi
}

test_port() {
    local port="$1"
    local protocol="${2:-tcp}"
    local description="$3"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_pass "Port $port ($description) is listening"
        return 0
    else
        log_fail "Port $port ($description) is not listening"
        log_verbose "Service may not be running or port not configured"
        return 1
    fi
}

test_connectivity() {
    local host="$1"
    local port="$2"
    local description="$3"
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        log_pass "Can connect to $description ($host:$port)"
        return 0
    else
        log_warn "Cannot connect to $description ($host:$port)"
        log_verbose "Check firewall and service configuration"
        return 1
    fi
}

test_ssl_cert() {
    local domain="$1"
    
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        local expiry
        expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$domain/fullchain.pem" 2>/dev/null | cut -d= -f2)
        log_pass "SSL certificate exists for $domain"
        log_verbose "Expires: $expiry"
        
        # Check if expiring soon (30 days)
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s 2>/dev/null)
        local now_epoch
        now_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        if [[ $days_left -lt 30 ]]; then
            log_warn "Certificate expires in $days_left days - renewal recommended"
        fi
        return 0
    else
        log_fail "SSL certificate not found for $domain"
        log_verbose "Run: certbot certonly -d $domain"
        return 1
    fi
}

test_dns_record() {
    local domain="$1"
    local record_type="$2"
    local expected_pattern="$3"
    local description="$4"
    
    local result
    result=$(dig +short "$domain" "$record_type" 2>/dev/null | head -1)
    
    if [[ -n "$result" ]]; then
        if [[ -z "$expected_pattern" ]] || echo "$result" | grep -q "$expected_pattern"; then
            log_pass "$description: $result"
            return 0
        else
            log_warn "$description found but doesn't match expected pattern"
            log_verbose "Found: $result | Expected pattern: $expected_pattern"
            return 1
        fi
    else
        log_fail "$description not found"
        log_verbose "DNS query: dig $domain $record_type"
        return 1
    fi
}

test_smtp_auth() {
    local hostname="$1"
    local port="${2:-587}"
    
    if command -v nc &>/dev/null || command -v netcat &>/dev/null; then
        local auth_supported
        auth_supported=$(echo -e "EHLO test\nQUIT" | timeout 5 nc "$hostname" "$port" 2>/dev/null | grep -i "AUTH")
        
        if [[ -n "$auth_supported" ]]; then
            log_pass "SMTP authentication supported on port $port"
            log_verbose "$auth_supported"
            return 0
        else
            log_warn "SMTP authentication not detected on port $port"
            return 1
        fi
    else
        log_warn "Cannot test SMTP auth (nc/netcat not installed)"
        return 1
    fi
}

test_starttls() {
    local hostname="$1"
    local port="${2:-587}"
    
    if command -v openssl &>/dev/null; then
        local starttls_result
        starttls_result=$(echo "QUIT" | timeout 5 openssl s_client -starttls smtp -connect "$hostname:$port" 2>&1 | grep -i "starttls")
        
        if [[ -n "$starttls_result" ]]; then
            log_pass "STARTTLS supported on port $port"
            return 0
        else
            log_warn "STARTTLS not detected on port $port"
            return 1
        fi
    else
        log_warn "Cannot test STARTTLS (openssl not installed)"
        return 1
    fi
}

# ============================================================================
# TEST SUITES
# ============================================================================

test_services() {
    print_section "Testing Services"
    
    log_info "Checking service status..."
    test_service "postfix" "Postfix (SMTP)"
    test_service "dovecot" "Dovecot (IMAP/POP3)"
    
    # Check database
    if systemctl is-active --quiet mariadb 2>/dev/null; then
        test_service "mariadb" "MariaDB"
    elif systemctl is-active --quiet mysql 2>/dev/null; then
        test_service "mysql" "MySQL"
    else
        log_fail "Database server not running"
        CRITICAL_FAILED=true
    fi
    
    # Check web server
    if systemctl is-active --quiet nginx 2>/dev/null; then
        test_service "nginx" "Nginx"
    elif systemctl is-active --quiet apache2 2>/dev/null; then
        test_service "apache2" "Apache"
    elif systemctl is-active --quiet httpd 2>/dev/null; then
        test_service "httpd" "Apache (httpd)"
    else
        log_warn "No web server detected (optional)"
    fi
}

test_network() {
    print_section "Testing Network Ports"
    
    log_info "Checking listening ports..."
    
    # SMTP ports
    test_port 25 tcp "SMTP"
    test_port 587 tcp "SMTP Submission (STARTTLS)"
    test_port 465 tcp "SMTPS (Legacy SSL)" || log_verbose "Port 465 optional"
    
    # IMAP ports
    test_port 143 tcp "IMAP (STARTTLS)"
    test_port 993 tcp "IMAPS (SSL)"
    
    # POP3 ports
    test_port 110 tcp "POP3 (STARTTLS)" || log_verbose "POP3 optional"
    test_port 995 tcp "POP3S (SSL)" || log_verbose "POP3 optional"
    
    # Web ports
    if systemctl is-active --quiet nginx 2>/dev/null || systemctl is-active --quiet apache2 2>/dev/null || systemctl is-active --quiet httpd 2>/dev/null; then
        test_port 80 tcp "HTTP"
        test_port 443 tcp "HTTPS"
    fi
}

test_ssl() {
    print_section "Testing SSL/TLS Configuration"
    
    # Find configured domains
    local domains=()
    if [[ -f /etc/postfix/main.cf ]]; then
        local mydomain
        mydomain=$(grep "^mydomain" /etc/postfix/main.cf | cut -d= -f2 | tr -d ' ')
        [[ -n "$mydomain" ]] && domains+=("$mydomain")
        
        local myhostname
        myhostname=$(grep "^myhostname" /etc/postfix/main.cf | cut -d= -f2 | tr -d ' ')
        [[ -n "$myhostname" ]] && domains+=("$myhostname")
    fi
    
    if [[ ${#domains[@]} -eq 0 ]]; then
        log_warn "No domains found to test SSL certificates"
        return 1
    fi
    
    log_info "Testing SSL certificates..."
    for domain in "${domains[@]}"; do
        test_ssl_cert "$domain"
    done
    
    # Test cipher strength
    if command -v openssl &>/dev/null && [[ -n "${domains[0]}" ]]; then
        log_info "Testing cipher configuration..."
        local ciphers
        ciphers=$(openssl s_client -connect "${domains[0]}:993" -brief 2>&1 | grep "Cipher" | head -1)
        if [[ -n "$ciphers" ]]; then
            log_pass "Cipher negotiation successful"
            log_verbose "$ciphers"
        fi
    fi
}

test_dns() {
    print_section "Testing DNS Records"
    
    # Get domain from postfix config
    local domain=""
    if [[ -f /etc/postfix/main.cf ]]; then
        domain=$(grep "^mydomain" /etc/postfix/main.cf | cut -d= -f2 | tr -d ' ')
    fi
    
    if [[ -z "$domain" ]]; then
        log_warn "Cannot determine domain from Postfix configuration"
        return 1
    fi
    
    local hostname
    hostname=$(grep "^myhostname" /etc/postfix/main.cf | cut -d= -f2 | tr -d ' ')
    
    log_info "Testing DNS records for $domain..."
    
    # A record for hostname
    test_dns_record "$hostname" "A" "" "A record for $hostname"
    
    # MX record
    test_dns_record "$domain" "MX" "" "MX record for $domain"
    
    # SPF record
    test_dns_record "$domain" "TXT" "v=spf1" "SPF record for $domain"
    
    # DMARC record
    test_dns_record "_dmarc.$domain" "TXT" "v=DMARC1" "DMARC record for $domain"
    
    # Reverse DNS (if we can detect IP)
    local server_ip
    server_ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    if [[ -n "$server_ip" ]]; then
        log_info "Testing reverse DNS for $server_ip..."
        local ptr
        ptr=$(dig +short -x "$server_ip" 2>/dev/null | head -1)
        if [[ -n "$ptr" ]]; then
            log_pass "Reverse DNS (PTR): $ptr"
        else
            log_warn "Reverse DNS (PTR) not configured"
            log_verbose "Contact your hosting provider to set PTR record"
        fi
    fi
}

test_mail_flow() {
    print_section "Testing Mail Flow"
    
    # Get hostname
    local hostname=""
    if [[ -f /etc/postfix/main.cf ]]; then
        hostname=$(grep "^myhostname" /etc/postfix/main.cf | cut -d= -f2 | tr -d ' ')
    fi
    
    if [[ -z "$hostname" ]]; then
        log_warn "Cannot determine hostname from configuration"
        return 1
    fi
    
    log_info "Testing SMTP connectivity..."
    test_connectivity "$hostname" 25 "SMTP"
    test_connectivity "$hostname" 587 "SMTP Submission"
    
    log_info "Testing SMTP features..."
    test_smtp_auth "$hostname" 587
    test_starttls "$hostname" 587
    
    log_info "Testing IMAP connectivity..."
    test_connectivity "$hostname" 993 "IMAPS"
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

generate_summary() {
    if [[ "$QUIET" == false ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${WHITE}Test Summary${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
        echo -e "${YELLOW}Warnings: $TESTS_WARNING${NC}"
        echo -e "${RED}Failed:   $TESTS_FAILED${NC}"
        echo ""
        
        if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNING -eq 0 ]]; then
            echo -e "${BOLD}${GREEN}✓ All tests passed!${NC}"
            echo "Your mail server appears to be configured correctly."
        elif [[ $TESTS_FAILED -eq 0 ]]; then
            echo -e "${BOLD}${YELLOW}⚠ Tests passed with warnings${NC}"
            echo "Your server is functional but some optional features have issues."
        else
            echo -e "${BOLD}${RED}✗ Some tests failed${NC}"
            if [[ "$CRITICAL_FAILED" == true ]]; then
                echo "Critical services are not running properly. Please review the failures above."
            else
                echo "Some components need attention. Review the failures above."
            fi
        fi
        echo ""
    fi
    
    # Write summary to report file
    if [[ -n "$REPORT_FILE" ]]; then
        {
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "TEST SUMMARY - $(date)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Passed:   $TESTS_PASSED"
            echo "Warnings: $TESTS_WARNING"
            echo "Failed:   $TESTS_FAILED"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        } >> "$REPORT_FILE"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --services) TEST_FILTER="services" ;;
            --network) TEST_FILTER="network" ;;
            --ssl) TEST_FILTER="ssl" ;;
            --dns) TEST_FILTER="dns" ;;
            --mail) TEST_FILTER="mail" ;;
            --verbose) VERBOSE=true ;;
            --quiet) QUIET=true ;;
            --report)
                REPORT_FILE="$2"
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --services    Test only services"
                echo "  --network     Test only network ports"
                echo "  --ssl         Test only SSL/TLS"
                echo "  --dns         Test only DNS records"
                echo "  --mail        Test only mail flow"
                echo "  --verbose     Show detailed output"
                echo "  --quiet       Minimal output"
                echo "  --report FILE Save report to file"
                echo "  --help        Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 3
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    
    print_header
    
    # Initialize report file
    if [[ -n "$REPORT_FILE" ]]; then
        echo "Mail Server Test Report - $(date)" > "$REPORT_FILE"
        echo "═══════════════════════════════════════════════════════════════════════" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
    
    # Run tests based on filter
    case "$TEST_FILTER" in
        services) test_services ;;
        network) test_network ;;
        ssl) test_ssl ;;
        dns) test_dns ;;
        mail) test_mail_flow ;;
        *)
            # Run all tests
            test_services
            test_network
            test_ssl
            test_dns
            test_mail_flow
            ;;
    esac
    
    generate_summary
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        if [[ "$CRITICAL_FAILED" == true ]]; then
            exit 2
        else
            exit 1
        fi
    fi
    
    exit 0
}

# Check if running as root
if [[ $EUID -ne 0 ]] && [[ "$QUIET" == false ]]; then
    echo -e "${YELLOW}Warning: Some tests may require root privileges${NC}"
    echo "Consider running: sudo $0 $*"
    echo ""
fi

main "$@"
