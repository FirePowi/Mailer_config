# Interactive Mail Server Installer - Quick Start Guide

## Overview

This script provides a **fully interactive, distribution-agnostic** mail server installation that:

✅ **Asks questions** instead of requiring command-line arguments  
✅ **Detects your Linux distribution** automatically (Debian, Ubuntu, RedHat, Fedora, CentOS, Arch, etc.)  
✅ **Maps package names** correctly for each distribution  
✅ **Installs and configures** Postfix, Dovecot, and all components  
✅ **Supports multiple domains** out of the box  
✅ **Generates heavily commented configurations** for learning  
✅ **Uses Certbot** for automatic SSL/TLS certificates  
✅ **Follows KISS principles** - simple, modular, easy to understand  

## Usage

Simply run the script as root - **no arguments needed**:

```bash
sudo ./install-mail-server.sh
```

The script will guide you through the installation with clear questions.

## What the Script Asks

### 1. Basic Configuration
- **Primary mail domain** (e.g., example.com)
- **Server hostname** (e.g., mail.example.com)
- **Admin email address**
- **Additional domains** (optional, supports multiple)

### 2. Component Selection

**Mandatory Components** (installed automatically):
- ✓ Postfix (SMTP server)
- ✓ Dovecot (IMAP/POP3 server)
- ✓ MariaDB (database)
- ✓ Certbot (SSL certificates)
- ✓ Policyd-SPF (SPF checking)
- ✓ PostfixAdmin (web management)

**Optional Components** (you choose):
- SpamAssassin (spam filtering)
- ClamAV (antivirus scanning)
- Rspamd (modern spam filter alternative)
- OpenDKIM (email authentication)

**Webmail Clients** (choose one or none):
- SnappyMail (recommended - modern, fast, file-based)
- Roundcube (feature-rich, mature)
- SOGo (full groupware with calendar and contacts)

### 3. SSL Certificates
- Option to obtain Let's Encrypt certificates immediately
- Automatic renewal configuration
- Secure permissions setup

## Supported Linux Distributions

### Debian Family (apt-get)
- Debian 10, 11, 12
- Ubuntu 18.04, 20.04, 22.04, 24.04
- Linux Mint
- Pop!_OS

### RedHat Family (yum/dnf)
- RedHat Enterprise Linux 7, 8, 9
- CentOS 7, 8, 9
- Fedora 35+
- Rocky Linux
- AlmaLinux

### Arch Family (pacman)
- Arch Linux
- Manjaro
- EndeavourOS

### SUSE Family (zypper)
- openSUSE Leap
- openSUSE Tumbleweed
- SUSE Linux Enterprise

## Key Features

### 1. Distribution-Aware Package Management

The script automatically detects your distribution and uses the correct:
- Package manager (apt-get, yum, dnf, pacman, zypper)
- Package names (they vary between distributions!)
- Service names
- Configuration paths

**Example**: Installing Dovecot
- Debian/Ubuntu: `dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd`
- RedHat/CentOS: `dovecot dovecot-mysql`
- Arch Linux: `dovecot` (all included)

### 2. Heavily Commented Configurations

Every generated configuration file includes **extensive comments** explaining:
- What each setting does
- Why it's configured that way
- What happens if you change it
- Security implications
- Performance considerations

**Example from main.cf**:
```
# Maximum size of any single email message (25MB here)
# Adjust based on your needs (value in bytes)
message_size_limit = 26214400

# Maximum size of a user's entire mailbox (0 = unlimited)
# Quota is better enforced at the Dovecot level
mailbox_size_limit = 0
```

Perfect for learning or for beginners!

### 3. Multi-Domain Support

The script:
- Asks for your primary domain
- Allows adding unlimited additional domains
- Creates database entries for all domains
- Configures virtual domain mapping
- Sets up separate mailboxes per domain

**Example**:
```
Domains: example.com, company.com, business.org
Users can be: john@example.com, jane@company.com, admin@business.org
```

### 4. Modular Component System

Choose exactly what you need:
- ✓ **Core components** (mandatory): Postfix, Dovecot, MariaDB, Certbot, Policyd-SPF, PostfixAdmin
- **Spam filtering**: SpamAssassin OR Rspamd
- **Antivirus**: ClamAV (optional)
- **Authentication**: OpenDKIM (optional)
- **Webmail**: SnappyMail (recommended), Roundcube, or SOGo (choose one or skip)

Each component is independently configurable!

### 5. Secure by Default

- Passwords auto-generated (32 characters)
- TLS 1.2+ only (old protocols disabled)
- Strong cipher suites
- File permissions set correctly
- Database user has minimal privileges
- SASL authentication required
- SPF checking enabled

### 6. Production-Ready Output

**Generated files**:
```
/etc/postfix/
├── main.cf                          # Main Postfix config (heavily commented)
├── master.cf                        # Service definitions (heavily commented)
├── mysql-virtual-domains.cf         # Domain lookup (with comments)
├── mysql-virtual-mailbox-maps.cf    # Mailbox mapping (with comments)
└── mysql-virtual-alias-maps.cf      # Alias mapping (with comments)

/etc/dovecot/
├── dovecot.conf                     # Main Dovecot config (heavily commented)
└── dovecot-sql.conf.ext            # SQL auth config (heavily commented)

/var/vmail/
├── example.com/
│   ├── john/Maildir/
│   └── jane/Maildir/
└── company.com/
    └── admin/Maildir/
```

## Step-by-Step Usage

### Step 1: Prepare Your Server

```bash
# Update your system
sudo apt-get update && sudo apt-get upgrade -y  # Debian/Ubuntu
# OR
sudo dnf update -y                              # Fedora/RHEL
# OR  
sudo pacman -Syu                                # Arch Linux

# Make sure you have a static IP address
ip addr show

# Configure your hostname
sudo hostnamectl set-hostname mail.example.com
```

### Step 2: Configure DNS (BEFORE running script)

Add these records to your DNS provider:

```dns
; A record for mail server
mail.example.com.  IN  A     YOUR_SERVER_IP

; MX record for email
example.com.       IN  MX  10  mail.example.com.

; Optional: SPF record (can be added later)
example.com.       IN  TXT    "v=spf1 mx ~all"
```

**Wait for DNS propagation** (can take up to 48 hours, usually minutes):
```bash
# Test DNS resolution
dig mail.example.com
nslookup mail.example.com
```

### Step 3: Download and Run the Script

```bash
# Download the script
wget https://your-repo/install-mail-server.sh
# OR clone the repo
git clone https://your-repo.git
cd your-repo

# Make it executable
chmod +x install-mail-server.sh

# Run as root
sudo ./install-mail-server.sh
```

### Step 4: Follow the Interactive Prompts

The script will ask you questions:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Basic Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enter your primary mail domain (e.g., example.com):
> example.com

Enter the mail server hostname: [mail.example.com]
> (press Enter to accept default)

Enter admin email address: [admin@example.com]
> admin@example.com

Do you want to add additional domains? [y/N]
> y

Enter additional domain (or press Enter to finish):
> company.com

Enter additional domain (or press Enter to finish):
> (press Enter to finish)
```

Then component selection:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Component Selection
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Postfix (SMTP Server) - MANDATORY
✓ Dovecot (IMAP/POP3 Server) - MANDATORY
✓ MariaDB (Database) - MANDATORY
✓ Certbot (SSL Certificates) - MANDATORY
✓ Policyd-SPF (SPF Checking) - MANDATORY
✓ PostfixAdmin (Web management interface) - MANDATORY

Install SpamAssassin? (spam filtering) [Y/n]
> y

Install ClamAV? (antivirus scanning) [y/N]
> n

Install OpenDKIM? (email authentication) [Y/n]
> y

Install Roundcube? (webmail interface) [y/N]
> n
```

### Step 5: Save the Generated Credentials

The script will generate and display secure passwords:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Password Generation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠  IMPORTANT: Save these passwords securely!

Database Password: Xy7mK9pL2nQ5vR8tW1zS4uY
PostfixAdmin Setup Password: Pq3mN6kJ9rT2wV5xZ8cF1gH

Press Enter to continue...
```

**SAVE THESE!** You'll need them later.

### Step 6: Wait for Installation

The script will:
- ✓ Install all packages (5-10 minutes depending on internet speed)
- ✓ Configure database and create tables
- ✓ Generate configuration files with comments
- ✓ Setup SSL certificates (if DNS is ready)
- ✓ Start and enable all services

### Step 7: Complete Post-Installation Steps

Follow the final instructions displayed by the script:

1. **Verify DNS records**
2. **Create your first email account**
3. **Test the configuration**
4. **Configure firewall**
5. **Monitor logs**

## Creating Email Accounts

### Method 1: Direct Database Insert

```sql
mysql -u root mail

-- Create a user
INSERT INTO mail_users (email, domain_id, password, enabled, name)
VALUES (
    'john@example.com',
    (SELECT id FROM mail_domains WHERE domain = 'example.com'),
    ENCRYPT('SecurePassword123', CONCAT('$6$', SUBSTRING(SHA(RAND()), -16))),
    1,
    'John Doe'
);

-- Verify
SELECT * FROM mail_users;
```

### Method 2: Using doveadm

```bash
# Generate password hash
doveadm pw -s SHA512-CRYPT -p SecurePassword123

# Copy the hash and insert into database
mysql -u root mail
INSERT INTO mail_users (email, domain_id, password, enabled)
VALUES ('john@example.com', 1, '{SHA512-CRYPT}$6$...', 1);
```

### Method 3: Using PostfixAdmin (Web Interface)

Access PostfixAdmin at: `https://mail.example.com/postfixadmin`

## Testing Your Mail Server

### Test SMTP (Sending)

```bash
# Test connection
telnet mail.example.com 25

# Or with SSL
openssl s_client -connect mail.example.com:587 -starttls smtp

# Send test email
EHLO mail.example.com
MAIL FROM:<john@example.com>
RCPT TO:<recipient@example.com>
DATA
Subject: Test Email

This is a test.
.
QUIT
```

### Test IMAP (Receiving)

```bash
# Test IMAPS
openssl s_client -connect mail.example.com:993

# Login
a LOGIN john@example.com password
b LIST "" "*"
c SELECT INBOX
d LOGOUT
```

### Test Authentication

```bash
# Test Dovecot authentication
doveadm auth test john@example.com

# Check if user can authenticate
telnet mail.example.com 143
a LOGIN john@example.com password
```

## Monitoring and Maintenance

### Check Logs

```bash
# Realtime mail log
tail -f /var/log/mail.log

# Filter for errors
grep -i error /var/log/mail.log
grep -i warning /var/log/mail.log

# Systemd journals
journalctl -u postfix -f
journalctl -u dovecot -f
```

### Service Management

```bash
# Check status
systemctl status postfix
systemctl status dovecot
systemctl status mariadb

# Reload configuration
postfix reload
systemctl reload dovecot

# Restart services
systemctl restart postfix
systemctl restart dovecot
```

### Mail Queue Management

```bash
# View queue
mailq

# Flush queue (retry delivery)
postqueue -f

# Delete specific message
postsuper -d MESSAGE_ID

# Delete all queued mail
postsuper -d ALL
```

## Configuration Files - Learning Guide

All generated configuration files include **extensive inline comments**. Read them to understand:

### Postfix main.cf
**Location**: `/etc/postfix/main.cf`

Sections explained:
- **Basic Settings**: Server identity and network configuration
- **Virtual Domain Configuration**: Multi-domain support
- **Message Size Limits**: Control email sizes
- **TLS/SSL Configuration**: Encryption settings (outgoing & incoming)
- **SASL Authentication**: User authentication
- **Relay Restrictions**: Who can send mail
- **Recipient/Sender/HELO Restrictions**: Anti-spam rules
- **Logging**: What to log and where
- **Performance Tuning**: Process limits and queue settings
- **Security Settings**: Disable dangerous features
- **Policyd-SPF**: SPF checking
- **Milter Configuration**: DKIM signing

### Postfix master.cf
**Location**: `/etc/postfix/master.cf`

Services explained:
- **smtp (port 25)**: Accept mail from other servers
- **submission (port 587)**: Authenticated mail submission (required TLS)
- **smtps (port 465)**: Legacy SSL wrapped SMTP
- **Internal services**: pickup, cleanup, qmgr, bounce, etc.
- **Transport services**: smtp, relay, lmtp
- **Policyd-SPF service**: SPF checking process

### Dovecot dovecot.conf
**Location**: `/etc/dovecot/dovecot.conf`

Sections explained:
- **Protocols**: IMAP, POP3, LMTP configuration
- **Network Settings**: Listening addresses
- **Logging**: What to log
- **SSL/TLS Configuration**: Certificate and cipher settings
- **Mail Location**: Where mailboxes are stored
- **Mailbox Configuration**: Special folders (Drafts, Sent, Trash, Spam)
- **Authentication**: How users prove identity
- **User/Password Database**: SQL lookups
- **Service Configuration**: IMAP, POP3, LMTP, Auth services
- **Protocol Settings**: IMAP, POP3, LMTP specific settings
- **Plugins**: Sieve, Quota configuration
- **Performance Tuning**: Caching and optimization

### MySQL Configuration Files
**Location**: `/etc/postfix/mysql-*.cf`

Each file explained:
- **mysql-virtual-domains.cf**: Check if domain is valid
- **mysql-virtual-mailbox-maps.cf**: Get mailbox location for user
- **mysql-virtual-alias-maps.cf**: Resolve email aliases

### Dovecot SQL Configuration
**Location**: `/etc/dovecot/dovecot-sql.conf.ext`

Queries explained:
- **password_query**: Verify user credentials
- **user_query**: Get mailbox location and permissions
- **iterate_query**: List all users (for admin tools)

## Troubleshooting

### Common Issues

#### 1. Certificates Not Obtained

**Problem**: Certbot fails to get certificates

**Solution**:
```bash
# Verify DNS is correct
dig mail.example.com
nslookup mail.example.com

# Make sure port 80 is open
sudo ufw allow 80/tcp

# Try again manually
sudo certbot certonly --standalone -d mail.example.com -d example.com

# Check if services are stopped
sudo systemctl stop postfix dovecot nginx apache2
```

#### 2. Cannot Send Mail

**Problem**: Mail stuck in queue

**Solution**:
```bash
# Check queue
mailq

# View detailed log
tail -f /var/log/mail.log

# Test configuration
postfix check

# Check if Postfix is running
systemctl status postfix

# Check for errors
grep -i error /var/log/mail.log
```

#### 3. Authentication Fails

**Problem**: Cannot login to IMAP/SMTP

**Solution**:
```bash
# Test Dovecot auth
doveadm auth test john@example.com password

# Check SQL connection
mysql -u mailuser -p mail
# (use database password from installation)

# View auth logs
tail -f /var/log/mail.log | grep auth

# Check dovecot-sql.conf.ext permissions
ls -la /etc/dovecot/dovecot-sql.conf.ext
# Should be: -rw------- (600)
```

#### 4. DNS Issues

**Problem**: Other servers cannot find your mail server

**Solution**:
```bash
# Test MX record
dig MX example.com

# Test A record  
dig mail.example.com

# Test from external DNS
dig @8.8.8.8 MX example.com

# Wait for propagation (up to 48 hours)
```

#### 5. Port Blocked

**Problem**: Cannot connect to mail ports

**Solution**:
```bash
# Check if ports are open
sudo netstat -tulpn | grep -E ':(25|587|993|995|143|110)'

# Check firewall
sudo ufw status

# Open required ports
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 993/tcp
sudo ufw allow 143/tcp

# Check if ISP blocks port 25 (common for residential IPs)
telnet mail.example.com 25  # from external network
```

## Security Best Practices

### 1. Regular Updates

```bash
# Keep system updated
sudo apt-get update && sudo apt-get upgrade  # Debian/Ubuntu
sudo dnf update                              # Fedora/RHEL
sudo pacman -Syu                             # Arch
```

### 2. Monitor Logs

```bash
# Setup log monitoring
sudo apt-get install logwatch
sudo logwatch --detail high --mailto admin@example.com --service postfix
```

### 3. Backup Regularly

```bash
# Backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
mysqldump mail > /backup/mail-$DATE.sql
tar -czf /backup/vmail-$DATE.tar.gz /var/vmail
tar -czf /backup/config-$DATE.tar.gz /etc/postfix /etc/dovecot
```

### 4. Configure Fail2ban

```bash
# Install fail2ban
sudo apt-get install fail2ban

# Configure for mail services
sudo nano /etc/fail2ban/jail.local
```

### 5. Enable DKIM, SPF, DMARC

Follow the post-installation instructions to set up:
- **SPF**: Add TXT record to DNS
- **DKIM**: Generate keys and add to DNS
- **DMARC**: Add policy to DNS

## Advanced Configuration

### Adding More Domains

```sql
mysql -u root mail

INSERT INTO mail_domains (domain, description)
VALUES ('newdomain.com', 'Additional domain');

-- Add users for new domain
INSERT INTO mail_users (email, domain_id, password, enabled)
VALUES ('user@newdomain.com', LAST_INSERT_ID(), 'HASH', 1);
```

### Email Aliases

```sql
-- Forward all mail from info@example.com to admin@example.com
INSERT INTO mail_aliases (source_email, destination_email, domain_id)
VALUES (
    'info@example.com',
    'admin@example.com',
    (SELECT id FROM mail_domains WHERE domain = 'example.com')
);
```

### Quota Management

Edit `/etc/dovecot/dovecot.conf` and adjust:
```
plugin {
  quota = maildir:User quota
  quota_rule = *:storage=10GB  # Change from 5GB to 10GB
}
```

## Support

### Where to Get Help

- **Postfix Documentation**: http://www.postfix.org/documentation.html
- **Dovecot Documentation**: https://doc.dovecot.org/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **System Logs**: `/var/log/mail.log`, `/var/log/syslog`

### Configuration Files to Check

All configuration files have extensive comments explaining each setting:
```
/etc/postfix/main.cf           # Start here for Postfix
/etc/postfix/master.cf         # Service definitions
/etc/dovecot/dovecot.conf     # Start here for Dovecot
/etc/dovecot/dovecot-sql.conf.ext  # Database auth
```

## Webmail Clients

The installer offers three modern webmail options:

### 1. SnappyMail (Recommended) ⭐

**Why choose SnappyMail:**
- 🚀 **Fast** - Modern, lightweight interface
- 📁 **File-based** - No database needed
- 🎨 **Clean UI** - Responsive, mobile-friendly
- 🔧 **Simple** - Easy setup and maintenance

**Access**: `https://mail.yourdomain.com`

**First-time setup:**
1. Visit the admin panel: `https://mail.yourdomain.com/?admin`
2. Default admin password: `12345` (change immediately!)
3. Configure IMAP: `localhost:993` (SSL)
4. Configure SMTP: `localhost:587` (STARTTLS)

**Best for:** Personal use, small teams, performance-focused deployments

### 2. Roundcube (Feature-Rich)

**Why choose Roundcube:**
- 🎯 **Mature** - Proven, stable, widely used
- 🔌 **Extensible** - 100+ plugins available
- 📧 **Feature-rich** - Comprehensive email features
- 🗄️ **Database-backed** - Reliable storage

**Access**: `https://mail.yourdomain.com`

**Features:**
- Modern "Elastic" skin (responsive design)
- Email filters via Managesieve
- HTML email composition
- Contact management
- Archive and search

**Best for:** Organizations, power users, feature-rich requirements

### 3. SOGo (Full Groupware)

**Why choose SOGo:**
- 📅 **Calendar** - Full CalDAV support
- 👥 **Contacts** - CardDAV address book
- 📱 **ActiveSync** - Native mobile device sync
- 🏢 **Groupware** - Complete collaboration suite

**Access**: `https://mail.yourdomain.com/SOGo`

**Features:**
- Email, calendar, contacts in one interface
- Microsoft ActiveSync for iPhone/Android
- Shared calendars and address books
- Outlook compatibility

**Best for:** Businesses, teams needing calendaring, mobile users

### Choosing the Right Webmail

| Feature | SnappyMail | Roundcube | SOGo |
|---------|------------|-----------|------|
| **Speed** | ⚡⚡⚡ Very Fast | ⚡⚡ Fast | ⚡ Moderate |
| **Resources** | 🟢 Low | 🟡 Medium | 🔴 High |
| **Calendar** | ❌ No | ❌ No | ✅ Yes |
| **Contacts** | ✅ Basic | ✅ Good | ✅ Advanced |
| **Mobile Sync** | ❌ No | ❌ No | ✅ ActiveSync |
| **Database** | ❌ Not needed | ✅ MySQL | ✅ MySQL |
| **Plugins** | 🟡 Some | ✅ Many | 🟢 Built-in |
| **Setup Complexity** | 🟢 Easy | 🟡 Medium | 🔴 Complex |

**Quick recommendation:**
- **Home user, small team:** SnappyMail
- **Power users, plugin enthusiasts:** Roundcube  
- **Business with calendar needs:** SOGo

## SSL/TLS Security

### Strong Cipher Suites (Built-in)

The installer automatically configures **Mozilla Modern** cipher suites across all components:

✅ **TLS 1.2+ only** - No SSL/TLS 1.0/1.1  
✅ **Strong ciphers** - ECDHE, AES-GCM, ChaCha20-Poly1305  
✅ **No weak ciphers** - Excludes 3DES, RC4, MD5, CBC mode  
✅ **Security headers** - HSTS, X-Frame-Options, CSP  
✅ **Forward secrecy** - DHE/ECDHE key exchange

**Components protected:**
- Postfix (SMTP) - Port 25, 587, 465
- Dovecot (IMAP/POP3) - Port 993, 995
- Nginx/Apache (HTTPS) - Port 443
- All webmail interfaces

### Security Audit Tools

Two additional scripts are provided for SSL/TLS security:

#### 1. Check SSL Ciphers (`check-ssl-ciphers.sh`)

Comprehensive audit tool that checks for weak or deprecated cipher suites:

```bash
sudo ./check-ssl-ciphers.sh
```

**What it checks:**
- ✓ Postfix TLS configuration
- ✓ Dovecot SSL settings
- ✓ Nginx/Apache HTTPS configs
- ✓ Live connection tests (SMTP, IMAP, HTTPS)
- ✓ Detection of weak ciphers (3DES, RC4, MD5, CBC)
- ✓ Protocol versions (SSLv2, SSLv3, TLS 1.0/1.1)
- ✓ Security headers (HSTS, X-Frame-Options)

**Output includes:**
- Current configuration analysis
- Vulnerability detection
- Cipher strength testing
- Recommendations for fixes

#### 2. Update SSL Config (`update-ssl-config.sh`)

Automated tool to upgrade existing configurations to modern cipher suites:

```bash
sudo ./update-ssl-config.sh
```

**What it does:**
- ✓ Backs up all config files (with timestamp)
- ✓ Updates Postfix to exclude weak ciphers
- ✓ Updates Dovecot to Mozilla Modern ciphers
- ✓ Updates Nginx/Apache SSL settings
- ✓ Adds security headers (HSTS)
- ✓ Tests configurations before restart
- ✓ Offers to restart services

**Safe to run:**
- Creates backups before any changes
- Tests configuration validity
- Asks before restarting services
- Can be run multiple times (idempotent)

### Mozilla Modern Cipher Suite

The installer uses these specific ciphers (in order of preference):

```
ECDHE-ECDSA-AES128-GCM-SHA256    # ECDSA + AES-128
ECDHE-RSA-AES128-GCM-SHA256      # RSA + AES-128
ECDHE-ECDSA-AES256-GCM-SHA384    # ECDSA + AES-256
ECDHE-RSA-AES256-GCM-SHA384      # RSA + AES-256
ECDHE-ECDSA-CHACHA20-POLY1305    # ECDSA + ChaCha20
ECDHE-RSA-CHACHA20-POLY1305      # RSA + ChaCha20
DHE-RSA-AES128-GCM-SHA256        # DHE + AES-128
DHE-RSA-AES256-GCM-SHA384        # DHE + AES-256
```

**Explicitly excluded:**
- aNULL, eNULL (no encryption)
- EXPORT (export-grade weakness)
- DES, 3DES (broken/deprecated)
- MD5 (collision attacks)
- RC2, RC4 (broken stream ciphers)
- PSK (often misconfigured)
- DSS/DSA (deprecated)
- CBC mode (BEAST/Lucky13 vulnerabilities)
- All SSLv2, SSLv3, TLS 1.0, TLS 1.1

### Testing Your Security

After installation, test your mail server security:

**1. Internal audit:**
```bash
sudo ./check-ssl-ciphers.sh
```

**2. External testing:**
- **Email Security:** https://www.checktls.com/
- **HTTPS/Webmail:** https://www.ssllabs.com/ssltest/
- **SMTP Test:** https://testssl.sh/

**3. Expected results:**
- SSL Labs: **A+ rating**
- Protocols: **TLS 1.2, TLS 1.3 only**
- Forward Secrecy: **Yes**
- Weak Ciphers: **None**

### Updating Cipher Suites

If you need to update an existing installation:

```bash
# Audit current configuration
sudo ./check-ssl-ciphers.sh

# Auto-update to modern ciphers
sudo ./update-ssl-config.sh

# Verify changes
sudo ./check-ssl-ciphers.sh
```

### Client Compatibility

**Modern cipher suites are compatible with:**
- ✓ Windows 10+, Server 2016+
- ✓ macOS 10.13+ (High Sierra)
- ✓ iOS 12+
- ✓ Android 8+ (Oreo)
- ✓ Chrome 79+, Firefox 74+
- ✓ Thunderbird 68+
- ✓ Outlook 2016+

**Not compatible with:**
- ✗ Windows XP, Vista, 7, 8
- ✗ Windows Server 2012 and older
- ✗ Old Android versions (< 8.0)
- ✗ Very old email clients (pre-2016)

If you need broader compatibility, you can adjust cipher suites, but security will be reduced.

## Summary

This interactive installer provides:
- ✅ **Zero-argument execution** - just run and answer questions
- ✅ **Multi-distribution support** - works on Debian, RedHat, Arch, etc.
- ✅ **Automatic package name mapping** - correct packages for your distro
- ✅ **Multi-domain support** - unlimited domains
- ✅ **Modular components** - choose what you need
- ✅ **Heavily commented configs** - learn as you go
- ✅ **Secure by default** - TLS 1.2+, strong ciphers, minimal privileges
- ✅ **Production ready** - complete, working mail server
- ✅ **KISS philosophy** - simple, clear, easy to understand

Perfect for both beginners learning mail servers and experienced admins who want a quick, well-documented setup!
