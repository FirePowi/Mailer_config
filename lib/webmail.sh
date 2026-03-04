#!/usr/bin/env bash

# ============================================================================
# Webmail Installation and Configuration Library
# ============================================================================
# This library provides functions for installing and configuring various
# webmail clients (SnappyMail, Roundcube, SOGo) with both nginx and Apache.
# ============================================================================

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ui.sh"
source "${SCRIPT_DIR}/packages.sh"

# ============================================================================
# WEBMAIL INSTALLATION
# ============================================================================

install_webmail() {
    if [ "$WEBMAIL_CHOICE" = "none" ]; then
        log_info "Webmail installation skipped"
        return
    fi
    
    print_section "Installing Webmail Client"
    
    # Install web server if not already installed
    log_step "Setting up web server..."
    if [ "$WEB_SERVER" = "nginx" ]; then
        install_package "nginx"
    elif [ "$WEB_SERVER" = "apache" ]; then
        install_package "apache"
    fi
    
    # Install common PHP dependencies
    log_step "Installing PHP and dependencies..."
    install_package "php"
    install_package "wget"
    install_package "unzip"
    
    case "$WEBMAIL_CHOICE" in
        snappymail)
            install_snappymail
            ;;
        roundcube)
            install_roundcube
            ;;
        sogo)
            install_sogo
            ;;
    esac
}

install_snappymail() {
    log_step "Installing SnappyMail..."
    
    # SnappyMail is a modern, fast, and lightweight webmail client
    # It doesn't require a database - it uses file storage
    # https://snappymail.eu/
    
    local SNAPPYMAIL_VERSION="latest"
    local INSTALL_DIR="/var/www/snappymail"
    local DOWNLOAD_URL="https://api.github.com/repos/the-djmaze/snappymail/releases/latest"
    
    # Get the latest release download URL
    log_info "Fetching latest SnappyMail release..."
    local ASSET_URL=$(curl -s "$DOWNLOAD_URL" | grep "browser_download_url.*snappymail.*zip" | head -1 | cut -d '"' -f 4)
    
    if [ -z "$ASSET_URL" ]; then
        log_error "Could not fetch SnappyMail download URL"
        return 1
    fi
    
    # Download SnappyMail
    log_step "Downloading SnappyMail..."
    cd /tmp || {
        log_error "Cannot change to /tmp directory"
        return 1
    }
    wget -q "$ASSET_URL" -O snappymail.zip
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Extract
    log_step "Extracting SnappyMail..."
    unzip -q snappymail.zip -d "$INSTALL_DIR"
    rm snappymail.zip
    
    # Set permissions
    # SnappyMail needs to write to its data directory
    chown -R www-data:www-data "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
    
    # Create data directory with write permissions
    mkdir -p "$INSTALL_DIR/data"
    chmod 750 "$INSTALL_DIR/data"
    
    log_success "SnappyMail installed to $INSTALL_DIR"
    
    # Configure web server virtual host
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_snappymail_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_snappymail_apache
    fi
}

install_roundcube() {
    log_step "Installing Roundcube..."
    
    # Roundcube is a mature, feature-rich webmail client
    # It requires MySQL database and is very customizable
    # https://roundcube.net/
    
    install_package "roundcube"
    
    # Create database for Roundcube
    log_step "Creating Roundcube database..."
    mysql -u root -p"$DB_PASSWORD" << EOSQL
CREATE DATABASE IF NOT EXISTS roundcubemail CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost' IDENTIFIED BY '$WEBMAIL_PASSWORD';
FLUSH PRIVILEGES;
EOSQL
    
    # Import Roundcube database schema
    local RC_SQL="/usr/share/roundcube/SQL/mysql.initial.sql"
    if [ -f "$RC_SQL" ]; then
        mysql -u root -p"$DB_PASSWORD" roundcubemail < "$RC_SQL"
        log_success "Roundcube database initialized"
    else
        log_warning "Roundcube SQL file not found at $RC_SQL"
    fi
    
    # Configure Roundcube
    configure_roundcube
    
    # Configure web server
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_roundcube_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_roundcube_apache
    fi
    
    log_success "Roundcube installed"
}

install_sogo() {
    log_step "Installing SOGo..."
    
    # SOGo is a full groupware solution with webmail, calendar, and contacts
    # It supports ActiveSync for mobile devices
    # https://sogo.nu/
    
    install_package "sogo"
    
    # Create database for SOGo
    log_step "Creating SOGo database..."
    mysql -u root -p"$DB_PASSWORD" << EOSQL
CREATE DATABASE IF NOT EXISTS sogo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON sogo.* TO 'sogo'@'localhost' IDENTIFIED BY '$WEBMAIL_PASSWORD';
FLUSH PRIVILEGES;
EOSQL
    
    # Configure SOGo
    configure_sogo
    
    # Configure web server
    if [ "$WEB_SERVER" = "nginx" ]; then
        configure_sogo_nginx
    elif [ "$WEB_SERVER" = "apache" ]; then
        configure_sogo_apache
    fi
    
    log_success "SOGo installed"
}

# ============================================================================
# WEBMAIL CONFIGURATION - SNAPPYMAIL
# ============================================================================

configure_snappymail_nginx() {
    log_step "Configuring nginx for SnappyMail..."
    
    local NGINX_CONF="/etc/nginx/sites-available/snappymail"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
# ============================================================================
# SNAPPYMAIL WEBMAIL - NGINX CONFIGURATION
# ============================================================================
# This configuration serves SnappyMail webmail client
# URL: https://mail.example.com/snappymail
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    # SSL Certificates (will be generated by Certbot)
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Document root
    root /var/www/snappymail;
    index index.php index.html;
    
    # Logging
    access_log /var/log/nginx/snappymail-access.log;
    error_log /var/log/nginx/snappymail-error.log;
    
    # Main location
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    # PHP handling
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    # Security: Deny access to sensitive files
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /data/ {
        deny all;
    }
    
    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOFNGINX
    
    # Replace placeholder with actual domain
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    
    # Enable site
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for SnappyMail"
}

configure_snappymail_apache() {
    log_step "Configuring Apache for SnappyMail..."
    
    local APACHE_CONF="/etc/apache2/sites-available/snappymail.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    # Handle different Apache config paths
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/snappymail.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
# ============================================================================
# SNAPPYMAIL WEBMAIL - APACHE CONFIGURATION
# ============================================================================
# This configuration serves SnappyMail webmail client
# URL: https://mail.example.com
# ============================================================================

<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    
    # Redirect HTTP to HTTPS
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    # SSL Configuration (will be managed by Certbot)
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder on
    SSLCompression off
    SSLSessionTickets off
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    # Document Root
    DocumentRoot /var/www/snappymail
    
    <Directory /var/www/snappymail>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php index.html
    </Directory>
    
    # Deny access to data directory
    <Directory /var/www/snappymail/data>
        Require all denied
    </Directory>
    
    # PHP Configuration
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/snappymail-error.log
    CustomLog ${APACHE_LOG_DIR}/snappymail-access.log combined
</VirtualHost>
EOFAPACHE
    
    # Replace placeholder with actual domain
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    # Enable required modules
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl rewrite proxy_fcgi setenvif headers
        a2ensite snappymail
    fi
    
    # Test and reload Apache
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for SnappyMail"
}

# ============================================================================
# WEBMAIL CONFIGURATION - ROUNDCUBE
# ============================================================================

configure_roundcube() {
    log_step "Configuring Roundcube..."
    
    local RC_CONFIG="/etc/roundcube/config.inc.php"
    
    # Backup original config if exists
    [ -f "$RC_CONFIG" ] && cp "$RC_CONFIG" "${RC_CONFIG}.backup"
    
    cat > "$RC_CONFIG" << EOFRC
<?php
/**
 * ============================================================================
 * ROUNDCUBE WEBMAIL CONFIGURATION
 * ============================================================================
 * This file configures Roundcube to connect to your mail server
 * ============================================================================
 */

// --------------------------------------------------
// DATABASE CONNECTION
// --------------------------------------------------
\$config['db_dsnw'] = 'mysql://roundcube:$WEBMAIL_PASSWORD@localhost/roundcubemail';

// --------------------------------------------------
// IMAP CONNECTION
// --------------------------------------------------
// Connect to Dovecot IMAP server
\$config['imap_host'] = 'ssl://localhost:993';
\$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// --------------------------------------------------
// SMTP CONNECTION
// --------------------------------------------------
// Connect to Postfix SMTP server for sending mail
\$config['smtp_host'] = 'tls://localhost:587';
\$config['smtp_user'] = '%u'; // Use IMAP username
\$config['smtp_pass'] = '%p'; // Use IMAP password
\$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer' => false,
        'verify_peer_name' => false,
    ),
);

// --------------------------------------------------
// GENERAL SETTINGS
// --------------------------------------------------
\$config['des_key'] = '$(openssl rand -base64 24)'; // Encryption key for session
\$config['product_name'] = 'Webmail'; // Name shown in interface
\$config['useragent'] = 'Roundcube Webmail'; // User agent
\$config['support_url'] = '';

// --------------------------------------------------
// USER INTERFACE
// --------------------------------------------------
\$config['language'] = 'en_US';
\$config['skin'] = 'elastic'; // Modern responsive skin
\$config['enable_spellcheck'] = true;

// --------------------------------------------------
// SECURITY
// --------------------------------------------------
\$config['session_lifetime'] = 30; // Minutes
\$config['ip_check'] = true; // Check IP for session security
\$config['identities_level'] = 0; // Users can create multiple identities

// --------------------------------------------------
// PLUGINS
// --------------------------------------------------
\$config['plugins'] = array(
    'archive',
    'zipdownload',
    'managesieve', // For managing mail filters
);

EOFRC
    
    log_success "Roundcube configured"
}

configure_roundcube_nginx() {
    log_step "Configuring Nginx for Roundcube..."
    
    local NGINX_CONF="/etc/nginx/sites-available/roundcube"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
# ============================================================================
# ROUNDCUBE WEBMAIL - NGINX CONFIGURATION
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    
    # SSL/TLS Configuration - Mozilla Modern (TLS 1.2+ only)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    
    # SSL Session Configuration
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    root /usr/share/roundcube;
    index index.php;
    
    access_log /var/log/nginx/roundcube-access.log;
    error_log /var/log/nginx/roundcube-error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(ht|git|svn) {
        deny all;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOFNGINX
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for Roundcube"
}

configure_roundcube_apache() {
    log_step "Configuring Apache for Roundcube..."
    
    local APACHE_CONF="/etc/apache2/sites-available/roundcube.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/roundcube.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    
    DocumentRoot /usr/share/roundcube
    
    <Directory /usr/share/roundcube>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        DirectoryIndex index.php
    </Directory>
    
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/var/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
    ErrorLog ${APACHE_LOG_DIR}/roundcube-error.log
    CustomLog ${APACHE_LOG_DIR}/roundcube-access.log combined
</VirtualHost>
EOFAPACHE
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl rewrite proxy_fcgi setenvif
        a2ensite roundcube
    fi
    
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for Roundcube"
}

# ============================================================================
# WEBMAIL CONFIGURATION - SOGO
# ============================================================================

configure_sogo() {
    log_step "Configuring SOGo..."
    
    local SOGO_CONFIG="/etc/sogo/sogo.conf"
    
    # Backup original config
    [ -f "$SOGO_CONFIG" ] && cp "$SOGO_CONFIG" "${SOGO_CONFIG}.backup"
    
    cat > "$SOGO_CONFIG" << EOFSOGO
/**
 * ============================================================================
 * SOGO GROUPWARE CONFIGURATION
 * ============================================================================
 * SOGo is a full groupware solution with webmail, calendar, and contacts
 * It supports ActiveSync for mobile device synchronization
 * ============================================================================
 */

{
  /* Database Configuration */
  SOGoProfileURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_user_profile";
  OCSFolderInfoURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_folder_info";
  OCSSessionsFolderURL = "mysql://sogo:$WEBMAIL_PASSWORD@localhost:3306/sogo/sogo_sessions_folder";
  
  /* Mail Server Configuration */
  SOGoIMAPServer = "localhost";
  SOGoSieveServer = "sieve://localhost:4190";
  SOGoSMTPServer = "localhost";
  SOGoMailDomain = "$PRIMARY_DOMAIN";
  SOGoMailingMechanism = "smtp";
  
  /* Authentication */
  SOGoForceExternalLoginWithEmail = YES;
  SOGoPasswordChangeEnabled = NO;
  
  /* Web Interface */
  SOGoPageTitle = "Mail";
  SOGoLanguage = "English";
  SOGoTimeZone = "UTC";
  
  /* ActiveSync for Mobile Devices */
  SOGoEnableEAS = YES;
  
  /* Calendar */
  SOGoFirstDayOfWeek = 0; // 0=Sunday, 1=Monday
  SOGoCalendarDefaultRoles = (
    "PublicViewer",
    "ConfidentialDAndTViewer"
  );
  
  /* Security */
  SOGoSessionTimeOut = 1800; // 30 minutes
}
EOFSOGO
    
    log_success "SOGo configured"
}

configure_sogo_nginx() {
    log_step "Configuring Nginx for SOGo..."
    
    local NGINX_CONF="/etc/nginx/sites-available/sogo"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    cat > "$NGINX_CONF" << 'EOFNGINX'
server {
    listen 80;
    listen [::]:80;
    server_name WEBMAIL_DOMAIN;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name WEBMAIL_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    access_log /var/log/nginx/sogo-access.log;
    error_log /var/log/nginx/sogo-error.log;
    
    # SOGo runs on port 20000 by default
    location / {
        proxy_pass http://127.0.0.1:20000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # ActiveSync
    location /Microsoft-Server-ActiveSync {
        proxy_pass http://127.0.0.1:20000/Microsoft-Server-ActiveSync;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOFNGINX
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$NGINX_CONF"
    mkdir -p /etc/nginx/sites-enabled
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    
    log_success "Nginx configured for SOGo"
}

configure_sogo_apache() {
    log_step "Configuring Apache for SOGo..."
    
    local APACHE_CONF="/etc/apache2/sites-available/sogo.conf"
    local WEBMAIL_DOMAIN="mail.${PRIMARY_DOMAIN}"
    
    if [ ! -d "/etc/apache2/sites-available" ]; then
        APACHE_CONF="/etc/httpd/conf.d/sogo.conf"
    fi
    
    cat > "$APACHE_CONF" << 'EOFAPACHE'
<VirtualHost *:80>
    ServerName WEBMAIL_DOMAIN
    Redirect permanent / https://WEBMAIL_DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName WEBMAIL_DOMAIN
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/WEBMAIL_DOMAIN/privkey.pem
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    
    # SOGo proxy configuration
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:20000/
    ProxyPassReverse / http://127.0.0.1:20000/
    
    # ActiveSync
    ProxyPass /Microsoft-Server-ActiveSync http://127.0.0.1:20000/Microsoft-Server-ActiveSync
    ProxyPassReverse /Microsoft-Server-ActiveSync http://127.0.0.1:20000/Microsoft-Server-ActiveSync
    
    ErrorLog ${APACHE_LOG_DIR}/sogo-error.log
    CustomLog ${APACHE_LOG_DIR}/sogo-access.log combined
</VirtualHost>
EOFAPACHE
    
    sed -i "s/WEBMAIL_DOMAIN/$WEBMAIL_DOMAIN/g" "$APACHE_CONF"
    
    if command -v a2enmod &>/dev/null; then
        a2enmod ssl proxy proxy_http headers
        a2ensite sogo
    fi
    
    if command -v apache2 &>/dev/null; then
        apache2ctl -t && systemctl reload apache2
    else
        httpd -t && systemctl reload httpd
    fi
    
    log_success "Apache configured for SOGo"
}
