#!/usr/bin/env bash
#
# DNS Configuration Helper Library
# Guides users through DNS setup step-by-step
#

# Source UI library for colors and formatting
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/ui.sh"

get_server_ip() {
    # Try multiple methods to get public IP
    ip=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    
    if [[ -z "$ip" ]]; then
        # Fallback to local IP if public IP detection fails
        ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
    fi
    
    echo "$ip"
}

test_dns_records() {
    print_section "Testing DNS Configuration"
    
    log_info "Detecting server IP address..."
    local server_ip
    server_ip=$(get_server_ip)
    
    if [[ -z "$server_ip" ]]; then
        log_error "Could not detect server IP address"
        server_ip="YOUR_SERVER_IP"
    else
        log_success "Server IP: $server_ip"
    fi
    
    SERVER_IP="$server_ip"
    
    log_info "Checking DNS records for $PRIMARY_DOMAIN..."
    echo ""
    
    # Check A record for hostname
    local resolved_ip
    resolved_ip=$(dig +short "$HOSTNAME" A 2>/dev/null | head -1)
    
    if [[ -n "$resolved_ip" ]]; then
        if [[ "$resolved_ip" == "$server_ip" ]]; then
            log_success "A record for $HOSTNAME resolves correctly to $server_ip"
        else
            log_warning "A record for $HOSTNAME resolves to $resolved_ip (expected: $server_ip)"
        fi
    else
        log_warning "A record for $HOSTNAME not found"
    fi
    
    # Check MX record
    local mx_record
    mx_record=$(dig +short "$PRIMARY_DOMAIN" MX 2>/dev/null | head -1)
    
    if [[ -n "$mx_record" ]]; then
        log_success "MX record found: $mx_record"
    else
        log_warning "MX record for $PRIMARY_DOMAIN not found"
    fi
    
    # Check reverse DNS
    local ptr_record
    ptr_record=$(dig +short -x "$server_ip" 2>/dev/null | head -1)
    
    if [[ -n "$ptr_record" ]]; then
        log_success "Reverse DNS (PTR) found: $ptr_record"
    else
        log_warning "Reverse DNS (PTR) not found for $server_ip"
    fi
    
    echo ""
}

show_dns_configuration() {
    print_section "DNS Configuration Guide"
    
    echo -e ""
    echo -e "${BOLD}${YELLOW}IMPORTANT: DNS Setup Required${NC}"
    echo -e ""

    echo -e ""
    echo -e "${BOLD}${YELLOW}IMPORTANT: DNS Setup Required${NC}"
    echo -e ""
    echo -e "Your mail server needs specific DNS records to work properly."
    echo -e "${GREEN}Don't worry!${NC} We'll guide you through this step-by-step."
    echo -e ""
    echo -e "${BOLD}${WHITE}Your Server Information:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Server IP:${NC}      ${WHITE}$SERVER_IP${NC}"
    echo -e "${CYAN}Hostname:${NC}       ${WHITE}$HOSTNAME${NC}"
    echo -e "${CYAN}Primary Domain:${NC} ${WHITE}$PRIMARY_DOMAIN${NC}"
    echo -e ""
    echo -e "${BOLD}${WHITE}Step-by-Step DNS Setup Guide:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
    echo -e "${YELLOW}Step 1: Log into your DNS provider${NC}"
    echo -e "   Common providers: Cloudflare, Namecheap, GoDaddy, Google Domains, etc."
    echo -e "   Look for \"DNS Management\", \"DNS Settings\", or \"Zone File Editor\""
    echo -e ""
    echo -e "${YELLOW}Step 2: Add A Record (required)${NC}"
    echo -e "   ${CYAN}Type:${NC}     A"
    echo -e "   ${CYAN}Name:${NC}     ${WHITE}mail${NC} (or ${WHITE}$HOSTNAME${NC})"
    echo -e "   ${CYAN}Value:${NC}    ${WHITE}$SERVER_IP${NC}"
    echo -e "   ${CYAN}TTL:${NC}      3600 (or automatic)"
    echo -e ""
    echo -e "   ${GREEN}What this does:${NC} Points mail.$PRIMARY_DOMAIN to your server"
    echo -e ""
    echo -e "${YELLOW}Step 3: Add MX Record (required)${NC}"
    echo -e "   ${CYAN}Type:${NC}     MX"
    echo -e "   ${CYAN}Name:${NC}     ${WHITE}@${NC} (or leave blank for root domain)"
    echo -e "   ${CYAN}Value:${NC}    ${WHITE}$HOSTNAME${NC} (or ${WHITE}mail.$PRIMARY_DOMAIN${NC})"
    echo -e "   ${CYAN}Priority:${NC} ${WHITE}10${NC}"
    echo -e "   ${CYAN}TTL:${NC}      3600"
    echo -e ""
    echo -e "   ${GREEN}What this does:${NC} Tells other servers where to send email for $PRIMARY_DOMAIN"
    echo -e ""
    echo -e "${YELLOW}Step 4: Add Autodiscover Records (recommended)${NC}"
    echo -e "   ${CYAN}Record 1:${NC}"
    echo -e "   Type:     A"
    echo -e "   Name:     ${WHITE}autoconfig${NC}"
    echo -e "   Value:    ${WHITE}$SERVER_IP${NC}"
    echo -e ""
    echo -e "   ${CYAN}Record 2:${NC}"
    echo -e "   Type:     A"
    echo -e "   Name:     ${WHITE}autodiscover${NC}"
    echo -e "   Value:    ${WHITE}$SERVER_IP${NC}"
    echo -e ""
    echo -e "   ${GREEN}What this does:${NC} Enables automatic email client configuration"
    echo -e ""
    echo -e "${YELLOW}Step 5: Add SPF Record (recommended)${NC}"
    echo -e "   ${CYAN}Type:${NC}     TXT"
    echo -e "   ${CYAN}Name:${NC}     ${WHITE}@${NC} (root domain)"
    echo -e "   ${CYAN}Value:${NC}    ${WHITE}\"v=spf1 mx a ~all\"${NC}"
    echo -e ""
    echo -e "   ${GREEN}What this does:${NC} Prevents email spoofing, improves deliverability"
    echo -e ""
    echo -e "${YELLOW}Step 6: Add DMARC Record (recommended)${NC}"
    echo -e "   ${CYAN}Type:${NC}     TXT"
    echo -e "   ${CYAN}Name:${NC}     ${WHITE}_dmarc${NC}"
    echo -e "   ${CYAN}Value:${NC}    ${WHITE}\"v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL\"${NC}"
    echo -e ""
    echo -e "   ${GREEN}What this does:${NC} Email authentication policy and reporting"
    echo -e ""
    echo -e "${BOLD}${WHITE}Additional Domains Configuration:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ ${#DOMAINS[@]} -gt 1 ]]; then
        echo ""
        log_info "For each additional domain, repeat steps 3, 5, and 6 above:"
        for domain in "${DOMAINS[@]}"; do
            if [[ "$domain" != "$PRIMARY_DOMAIN" ]]; then
                echo "  • $domain"
            fi
        done
    fi
    
    echo -e ""
    echo -e "${BOLD}${WHITE}Reverse DNS (PTR Record):${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
    echo -e "${YELLOW}Important:${NC} Contact your ${BOLD}server/VPS provider${NC} to set this up."
    echo -e "They control the reverse DNS for $SERVER_IP"
    echo -e ""
    echo -e "${CYAN}What to request:${NC}"
    echo -e "\"Please set the PTR record for $SERVER_IP to point to $HOSTNAME\""
    echo -e ""
    echo -e "${GREEN}What this does:${NC} Prevents your emails from being marked as spam"
    echo -e ""
    echo -e "${BOLD}${WHITE}How to Check DNS Records:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
    echo -e "After adding DNS records, verify them with these commands:"
    echo -e ""
    echo -e "${CYAN}Check A record:${NC}"
    echo -e "   dig $HOSTNAME A"
    echo -e ""
    echo -e "${CYAN}Check MX record:${NC}"
    echo -e "   dig $PRIMARY_DOMAIN MX"
    echo -e ""
    echo -e "${CYAN}Check SPF record:${NC}"
    echo -e "   dig $PRIMARY_DOMAIN TXT"
    echo -e ""
    echo -e "${CYAN}Check reverse DNS:${NC}"
    echo -e "   dig -x $SERVER_IP"
    echo -e ""
    echo -e "${GREEN}Or use online tools:${NC}"
    echo -e "   • https://mxtoolbox.com/"
    echo -e "   • https://www.whatsmydns.net/"
    echo -e ""
    echo -e "${BOLD}${YELLOW}⏰ DNS Propagation Time:${NC}"
    echo -e "DNS changes can take 15 minutes to 48 hours to propagate worldwide."
    echo -e "You can continue with the installation - the server will be ready when DNS propagates."
    echo -e ""
    echo -e "${BOLD}${WHITE}Quick Copy-Paste Records (for your DNS provider):${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    echo -e ""
    echo -e "${BOLD}${WHITE}Quick Copy-Paste Records (for your DNS provider):${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e ""
    echo "# A Records"
    echo "mail                A       $SERVER_IP"
    echo "autoconfig          A       $SERVER_IP"
    echo "autodiscover        A       $SERVER_IP"
    echo ""
    echo "# MX Record"
    echo "@                   MX 10   $HOSTNAME."
    echo ""
    echo "# TXT Records (SPF and DMARC)"
    echo "@                   TXT     \"v=spf1 mx a ~all\""
    echo "_dmarc              TXT     \"v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL\""
    echo ""
    echo -e "${CYAN}Note:${NC} The dot after $HOSTNAME is important for the MX record!"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if ask_yes_no "Have you added these DNS records (or want to continue anyway)?" "n"; then
        log_success "Continuing with installation..."
    else
        log_info "No problem! You can run this script again after setting up DNS."
        log_info "Your DNS records are saved above for reference."
        echo ""
        if ask_yes_no "Do you want to continue anyway?" "n"; then
            log_warning "Continuing without DNS verification..."
        else
            log_info "Installation cancelled. Run this script again when DNS is ready!"
            exit 0
        fi
    fi
}

interactive_dns_setup() {
    print_section "Interactive DNS Setup Assistant"
    
    echo ""
    printf "${BOLD}${CYAN}Welcome to the DNS Setup Assistant!${NC}\n\n"
    echo "We'll walk you through setting up DNS records step-by-step."
    echo "This will only take a few minutes."
    echo ""
    printf "${GREEN}What you'll need:${NC}\n"
    echo "• Access to your domain's DNS settings"
    echo "• Your domain registrar login (GoDaddy, Namecheap, etc.)"
    echo "  OR Cloudflare account if you use their DNS"
    echo ""
    printf "${YELLOW}Don't worry if you're not sure - we'll guide you!${NC}\n"
    echo ""
    
    echo -ne "${YELLOW}Ready to start DNS setup? [Y/n]: ${NC}"
    read -r dns_ready || true
    dns_ready="${dns_ready:-y}"
    if [[ ! "$dns_ready" =~ ^[Yy]$ ]]; then
        log_warning "Skipping DNS setup for now"
        return 0
    fi
    
    # Guide through each DNS provider
    echo ""
    echo -e "${YELLOW}Where is your domain's DNS managed?${NC}"
    echo -e "${CYAN}1)${NC} Cloudflare"
    echo -e "${CYAN}2)${NC} GoDaddy"
    echo -e "${CYAN}3)${NC} Namecheap"
    echo -e "${CYAN}4)${NC} Google Domains / Google Cloud DNS"
    echo -e "${CYAN}5)${NC} Other / Not sure"
    echo ""
    
    local dns_provider
    dns_provider=$(ask_question "Select your DNS provider [1-5]:" "5")
    
    case "$dns_provider" in
        1)
            show_cloudflare_guide
            ;;
        2)
            show_godaddy_guide
            ;;
        3)
            show_namecheap_guide
            ;;
        4)
            show_google_guide
            ;;
        *)
            show_generic_guide
            ;;
    esac
}

show_cloudflare_guide() {
    echo ""
    printf "${BOLD}${CYAN}Cloudflare DNS Setup:${NC}\n\n"
    printf "${YELLOW}1.${NC} Go to: https://dash.cloudflare.com/\n"
    printf "${YELLOW}2.${NC} Select your domain: ${WHITE}$PRIMARY_DOMAIN${NC}\n"
    printf "${YELLOW}3.${NC} Click \"DNS\" in the top menu\n"
    printf "${YELLOW}4.${NC} Click \"Add record\" button\n\n"
    printf "${BOLD}Add these 3 A records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: A    | Name: mail          | IPv4: $SERVER_IP | Proxy: OFF"
    echo "Type: A    | Name: autoconfig    | IPv4: $SERVER_IP | Proxy: OFF"  
    echo "Type: A    | Name: autodiscover  | IPv4: $SERVER_IP | Proxy: OFF"
    echo ""
    printf "${YELLOW}IMPORTANT:${NC} Turn ${BOLD}OFF${NC} the orange cloud (proxy) for mail records!\n\n"
    printf "${BOLD}Add MX record:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: MX   | Name: @             | Server: $HOSTNAME | Priority: 10"
    echo ""
    printf "${BOLD}Add TXT records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: TXT  | Name: @             | Content: v=spf1 mx a ~all"
    echo "Type: TXT  | Name: _dmarc        | Content: v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
    echo ""
    printf "${GREEN}✓ Done!${NC} Cloudflare DNS updates usually take 2-5 minutes.\n"
    echo ""
    pause_for_user
}

show_godaddy_guide() {
    echo ""
    printf "${BOLD}${CYAN}GoDaddy DNS Setup:${NC}\n\n"
    printf "${YELLOW}1.${NC} Go to: https://dcc.godaddy.com/manage/dns\n"
    printf "${YELLOW}2.${NC} Find domain: ${WHITE}$PRIMARY_DOMAIN${NC} and click \"DNS\"\n"
    printf "${YELLOW}3.${NC} Scroll to \"Records\" section\n"
    printf "${YELLOW}4.${NC} Click \"Add\" for each record below\n\n"
    printf "${BOLD}A Records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: A    | Name: mail          | Value: $SERVER_IP | TTL: 1 Hour"
    echo "Type: A    | Name: autoconfig    | Value: $SERVER_IP | TTL: 1 Hour"
    echo "Type: A    | Name: autodiscover  | Value: $SERVER_IP | TTL: 1 Hour"
    echo ""
    printf "${BOLD}MX Record:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: MX   | Name: @             | Value: $HOSTNAME | Priority: 10 | TTL: 1 Hour"
    echo ""
    printf "${BOLD}TXT Records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: TXT  | Name: @             | Value: v=spf1 mx a ~all"
    echo "Type: TXT  | Name: _dmarc        | Value: v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
    echo ""
    printf "${GREEN}✓ Done!${NC} GoDaddy DNS updates usually take 10-30 minutes.\n"
    echo ""
    pause_for_user
}

show_namecheap_guide() {
    echo ""
    printf "${BOLD}${CYAN}Namecheap DNS Setup:${NC}\n\n"
    printf "${YELLOW}1.${NC} Go to: https://ap.www.namecheap.com/domains/list/\n"
    printf "${YELLOW}2.${NC} Click \"Manage\" next to: ${WHITE}$PRIMARY_DOMAIN${NC}\n"
    printf "${YELLOW}3.${NC} Click \"Advanced DNS\" tab\n"
    printf "${YELLOW}4.${NC} Click \"Add New Record\" for each entry\n\n"
    printf "${BOLD}A Records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: A Record  | Host: mail          | Value: $SERVER_IP"
    echo "Type: A Record  | Host: autoconfig    | Value: $SERVER_IP"
    echo "Type: A Record  | Host: autodiscover  | Value: $SERVER_IP"
    echo ""
    printf "${BOLD}MX Record:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: MX Record | Host: @             | Value: $HOSTNAME | Priority: 10"
    echo ""
    printf "${BOLD}TXT Records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Type: TXT Record | Host: @            | Value: v=spf1 mx a ~all"
    echo "Type: TXT Record | Host: _dmarc       | Value: v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
    echo ""
    printf "${GREEN}✓ Done!${NC} Namecheap DNS updates usually take 5-30 minutes.\n"
    echo ""
    pause_for_user
}

show_google_guide() {
    echo ""
    printf "${BOLD}${CYAN}Google Domains / Cloud DNS Setup:${NC}\n\n"
    printf "${YELLOW}1.${NC} Go to: https://domains.google.com/ (or cloud.google.com/dns)\n"
    printf "${YELLOW}2.${NC} Click your domain: ${WHITE}$PRIMARY_DOMAIN${NC}\n"
    printf "${YELLOW}3.${NC} Click \"DNS\" in the left menu\n"
    printf "${YELLOW}4.${NC} Scroll to \"Custom records\" and click \"Manage custom records\"\n\n"
    printf "${BOLD}Add these records:${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Host name     | Type | TTL  | Data"
    echo "mail          | A    | 3600 | $SERVER_IP"
    echo "autoconfig    | A    | 3600 | $SERVER_IP"
    echo "autodiscover  | A    | 3600 | $SERVER_IP"
    echo "@             | MX   | 3600 | 10 $HOSTNAME"
    echo "@             | TXT  | 3600 | v=spf1 mx a ~all"
    echo "_dmarc        | TXT  | 3600 | v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
    echo ""
    printf "${GREEN}✓ Done!${NC} Google DNS updates usually take 5-15 minutes.\n"
    echo ""
    pause_for_user
}

show_generic_guide() {
    echo ""
    printf "${BOLD}${CYAN}Generic DNS Setup Guide:${NC}\n\n"
    echo "Look for these sections in your DNS control panel:"
    echo "• \"DNS Management\""
    echo "• \"DNS Settings\""  
    echo "• \"Zone File Editor\""
    echo "• \"Manage DNS Records\""
    echo ""
    printf "${BOLD}You need to add these records:${NC}\n\n"
    printf "${YELLOW}A Records (3 entries):${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Name/Host          | Type | Value/Points To"
    echo "mail               | A    | $SERVER_IP"
    echo "autoconfig         | A    | $SERVER_IP"
    echo "autodiscover       | A    | $SERVER_IP"
    echo ""
    printf "${YELLOW}MX Record (1 entry):${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Name/Host          | Type | Value/Points To      | Priority"
    echo "@  (or blank)      | MX   | $HOSTNAME           | 10"
    echo ""
    printf "${YELLOW}TXT Records (2 entries):${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Name/Host          | Type | Value/Content"
    echo "@  (or blank)      | TXT  | v=spf1 mx a ~all"
    echo "_dmarc             | TXT  | v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL"
    echo ""
    printf "${GREEN}✓ Save each record after adding it!${NC}\n"
    echo ""
    pause_for_user
}
