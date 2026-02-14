#!/usr/bin/env bash

# ============================================================================
# Email Client Autodiscovery Library
# ============================================================================
# This library provides functions for setting up email client autoconfiguration
# for both Thunderbird (autoconfig) and Outlook (autodiscover).
# ============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui.sh"

# ============================================================================
# AUTODISCOVER AND AUTOCONFIG
# ============================================================================

setup_autodiscover() {
    print_section "Setting up Email Client Autoconfiguration"
    
    log_info "Configuring Autodiscover (Outlook) and Autoconfig (Thunderbird)..."
    
    for DOMAIN in "${DOMAINS[@]}"; do
        log_step "Setting up autoconfiguration for $DOMAIN"
        
        # Create directory structure
        if [ "$WEB_SERVER" = "nginx" ]; then
            create_autodiscover_nginx "$DOMAIN"
        elif [ "$WEB_SERVER" = "apache" ]; then
            create_autodiscover_apache "$DOMAIN"
        fi
        
        # Create XML configuration files
        create_autoconfig_xml "$DOMAIN"
        create_autodiscover_xml "$DOMAIN"
    done
    
    log_success "Email client autoconfiguration setup complete"
}

create_autoconfig_xml() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    
    mkdir -p "${AUTOCONFIG_DIR}/mail"
    
    # Mozilla Thunderbird autoconfig
    cat > "${AUTOCONFIG_DIR}/mail/config-v1.1.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="${DOMAIN}">
    <domain>${DOMAIN}</domain>
    <displayName>${DOMAIN} Mail</displayName>
    <displayShortName>${DOMAIN}</displayShortName>
    
    <!-- Incoming Mail (IMAP) -->
    <incomingServer type="imap">
      <hostname>mail.${DOMAIN}</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    
    <!-- Incoming Mail (POP3) - Optional -->
    <incomingServer type="pop3">
      <hostname>mail.${DOMAIN}</hostname>
      <port>995</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    
    <!-- Outgoing Mail (SMTP) -->
    <outgoingServer type="smtp">
      <hostname>mail.${DOMAIN}</hostname>
      <port>587</port>
      <socketType>STARTTLS</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    
    <!-- Alternative SMTP (SSL) -->
    <outgoingServer type="smtp">
      <hostname>mail.${DOMAIN}</hostname>
      <port>465</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    
    <documentation url="https://mail.${DOMAIN}/">
      <descr lang="en">General information about this mail server</descr>
    </documentation>
  </emailProvider>
</clientConfig>
EOF
    
    chmod 644 "${AUTOCONFIG_DIR}/mail/config-v1.1.xml"
    log_success "Created Thunderbird autoconfig for $DOMAIN"
}

create_autodiscover_xml() {
    local DOMAIN="$1"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    mkdir -p "${AUTODISCOVER_DIR}/autodiscover"
    mkdir -p "${AUTODISCOVER_DIR}/Autodiscover"
    
    # Microsoft Outlook Autodiscover
    local AUTODISCOVER_XML="${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml"
    cat > "$AUTODISCOVER_XML" << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/responseschema/2006">
  <Response xmlns="http://schemas.microsoft.com/exchange/autodiscover/outlook/responseschema/2006a">
    <Account>
      <AccountType>email</AccountType>
      <Action>settings</Action>
      <Protocol>
        <Type>IMAP</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>993</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
      </Protocol>
      <Protocol>
        <Type>SMTP</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>587</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>off</SSL>
        <Encryption>TLS</Encryption>
        <AuthRequired>on</AuthRequired>
        <UsePOPAuth>on</UsePOPAuth>
        <SMTPLast>off</SMTPLast>
      </Protocol>
      <Protocol>
        <Type>POP3</Type>
        <Server>mail.DOMAIN_PLACEHOLDER</Server>
        <Port>995</Port>
        <LoginName>EMAIL_PLACEHOLDER</LoginName>
        <DomainRequired>off</DomainRequired>
        <SPA>off</SPA>
        <SSL>on</SSL>
        <AuthRequired>on</AuthRequired>
      </Protocol>
    </Account>
  </Response>
</Autodiscover>
XMLEOF
    
    # Replace placeholders with actual domain
    sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN}/g" "$AUTODISCOVER_XML"
    sed -i "s/EMAIL_PLACEHOLDER/%EMAILADDRESS%/g" "$AUTODISCOVER_XML"
    
    # Copy to both lowercase and uppercase paths (some clients expect different cases)
    cp "$AUTODISCOVER_XML" "${AUTODISCOVER_DIR}/Autodiscover/Autodiscover.xml"
    
    chmod 644 "${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml"
    chmod 644 "${AUTODISCOVER_DIR}/Autodiscover/Autodiscover.xml"
    
    log_success "Created Outlook Autodiscover for $DOMAIN"
}

create_autodiscover_nginx() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    # Thunderbird autoconfig vhost
    cat > "/etc/nginx/sites-available/autoconfig-${DOMAIN}" << EOF
server {
    listen 80;
    server_name autoconfig.${DOMAIN};
    
    root ${AUTOCONFIG_DIR};
    
    location /.well-known/autoconfig/mail/config-v1.1.xml {
        alias ${AUTOCONFIG_DIR}/mail/config-v1.1.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    location /mail/config-v1.1.xml {
        alias ${AUTOCONFIG_DIR}/mail/config-v1.1.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    access_log /var/log/nginx/autoconfig-${DOMAIN}-access.log;
    error_log /var/log/nginx/autoconfig-${DOMAIN}-error.log;
}
EOF
    
    # Outlook autodiscover vhost
    cat > "/etc/nginx/sites-available/autodiscover-${DOMAIN}" << EOF
server {
    listen 80;
    server_name autodiscover.${DOMAIN};
    
    root ${AUTODISCOVER_DIR};
    
    location ~ ^/(autodiscover|Autodiscover)/autodiscover.xml {
        alias ${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml;
        types { application/xml xml; }
        add_header Content-Type "application/xml; charset=utf-8";
    }
    
    access_log /var/log/nginx/autodiscover-${DOMAIN}-access.log;
    error_log /var/log/nginx/autodiscover-${DOMAIN}-error.log;
}
EOF
    
    # Enable sites
    ln -sf "/etc/nginx/sites-available/autoconfig-${DOMAIN}" "/etc/nginx/sites-enabled/"
    ln -sf "/etc/nginx/sites-available/autodiscover-${DOMAIN}" "/etc/nginx/sites-enabled/"
    
    log_success "Created nginx configuration for $DOMAIN autoconfiguration"
}

create_autodiscover_apache() {
    local DOMAIN="$1"
    local AUTOCONFIG_DIR="/var/www/autoconfig-${DOMAIN}"
    local AUTODISCOVER_DIR="/var/www/autodiscover-${DOMAIN}"
    
    # Determine Apache config directory
    local APACHE_CONF_DIR=""
    if [ -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF_DIR="/etc/apache2/sites-available"
    elif [ -d "/etc/httpd/conf.d" ]; then
        APACHE_CONF_DIR="/etc/httpd/conf.d"
    fi
    
    # Thunderbird autoconfig vhost
    cat > "${APACHE_CONF_DIR}/autoconfig-${DOMAIN}.conf" << EOF
<VirtualHost *:80>
    ServerName autoconfig.${DOMAIN}
    DocumentRoot ${AUTOCONFIG_DIR}
    
    <Directory ${AUTOCONFIG_DIR}>
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    Alias /.well-known/autoconfig/mail/config-v1.1.xml ${AUTOCONFIG_DIR}/mail/config-v1.1.xml
    Alias /mail/config-v1.1.xml ${AUTOCONFIG_DIR}/mail/config-v1.1.xml
    
    <Files "config-v1.1.xml">
        Header set Content-Type "application/xml; charset=utf-8"
    </Files>
    
    ErrorLog \${APACHE_LOG_DIR}/autoconfig-${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/autoconfig-${DOMAIN}-access.log combined
</VirtualHost>
EOF
    
    # Outlook autodiscover vhost
    cat > "${APACHE_CONF_DIR}/autodiscover-${DOMAIN}.conf" << EOF
<VirtualHost *:80>
    ServerName autodiscover.${DOMAIN}
    DocumentRoot ${AUTODISCOVER_DIR}
    
    <Directory ${AUTODISCOVER_DIR}>
        Require all granted
        Options -Indexes +FollowSymLinks
    </Directory>
    
    AliasMatch (?i)^/(autodiscover|Autodiscover)/autodiscover.xml ${AUTODISCOVER_DIR}/autodiscover/autodiscover.xml
    
    <Files "autodiscover.xml">
        Header set Content-Type "application/xml; charset=utf-8"
    </Files>
    
    ErrorLog \${APACHE_LOG_DIR}/autodiscover-${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/autodiscover-${DOMAIN}-access.log combined
</VirtualHost>
EOF
    
    # Enable sites (on Debian/Ubuntu)
    if [ -d "/etc/apache2/sites-enabled" ]; then
        a2ensite "autoconfig-${DOMAIN}" || true
        a2ensite "autodiscover-${DOMAIN}" || true
    fi
    
    log_success "Created Apache configuration for $DOMAIN autoconfiguration"
}
