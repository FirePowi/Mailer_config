# Installation Guide

Complete step-by-step guide to installing your mail server.

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [System Requirements](#system-requirements)
3. [Installation Steps](#installation-steps)
4. [Component Selection](#component-selection)
5. [DNS Configuration](#dns-configuration)
6. [Post-Installation](#post-installation)
7. [Troubleshooting](#troubleshooting)

## Before You Begin

You need:
- A server with a supported Linux distribution
- Root/sudo access
- A registered domain name
- Basic command line knowledge (optional - we guide you!)

## System Requirements

### Hardware
- **CPU**: 1+ cores (2+ recommended)
- **RAM**: 2 GB minimum, 4 GB recommended
- **Disk**: 20 GB minimum (more for email storage)
- **Network**: Static IP address required

### Supported Operating Systems
- Debian 10, 11, 12
- Ubuntu 18.04, 20.04, 22.04, 24.04 LTS
- RHEL / CentOS / Rocky / Alma 7, 8, 9
- Fedora 35+
- Arch Linux
- Derivatives of the above

## Installation Steps

### 1. Download Installer

```bash
git clone gh:FirePowi/Mailer_config
cd Mailer_config/.specify/scripts/bash
chmod +x install.sh
```

### 2. Run Installer

```bash
sudo ./install.sh
```

### 3. Answer Questions

The installer will ask:

**Domain Configuration:**
- Primary domain (e.g., example.com)
- Hostname (e.g., mail.example.com)
- Admin email address
- Additional domains (optional)

**Component Selection:**
- SpamAssassin (spam filtering)
- ClamAV (antivirus)
- OpenDKIM (email authentication)
- Rspamd (alternative spam filter)

**Webmail Client:**
- SnappyMail (recommended)
- Roundcube
- SOGo
- None

**Web Server:**
- Nginx (recommended)
- Apache
- Auto-detect

### 4. DNS Configuration

The installer will guide you through DNS setup with:
- Provider-specific instructions (Cloudflare, GoDaddy, etc.)
- Copy-paste ready records
- Explanation of each record's purpose

See [DNS Configuration Guide](DNS.md) for detailed information.

### 5. Wait for Installation

The installer will:
- Install packages (~5-15 minutes)
- Configure services
- Generate SSL certificates
- Set up databases
- Configure security settings

### 6. Save Credentials

The installer displays important credentials:
- Database password
- PostfixAdmin setup password
- Webmail database password (if applicable)

**⚠️ IMPORTANT:** Save these securely!

## Component Selection

### Mandatory Components

These are always installed:
- **Postfix** - SMTP mail server
- **Dovecot** - IMAP/POP3 server
- **MariaDB** - Database backend
- **Certbot** - SSL certificate management
- **Policyd-SPF** - SPF verification
- **PostfixAdmin** - Web management interface

### Optional: Anti-Spam

**SpamAssassin** (Recommended)
- Content-based spam filtering
- Highly effective
- Resource intensive (~500 MB RAM)

**Rspamd** (Alternative)
- Modern spam filter
- Lower resource usage
- Fewer false positives

Choose one or neither.

### Optional: Antivirus

**ClamAV**
- Scans email attachments for viruses
- High memory usage (~1 GB RAM)
- Recommended for organizations
- Not needed for personal use

### Optional: Email Authentication

**OpenDKIM** (Recommended)
- Signs outgoing emails
- Improves deliverability
- Prevents spoofing
- Low resource usage

### Webmail Clients

**SnappyMail** (Recommended)
- Modern, fast interface
- No database required
- Easy to maintain
- Perfect for personal use

**Roundcube**
- Feature-rich
- Outlook-like interface
- Plugin ecosystem
- Good for businesses

**SOGo**
- Full groupware (email + calendar + contacts)
- ActiveSync support
- CardDAV / CalDAV
- Best for organizations

**None**
- Skip webmail entirely
- Use desktop email client only

## DNS Configuration

See [DNS Configuration Guide](DNS.md) for:
- Step-by-step setup for popular providers
- Copy-paste ready records
- Testing and verification
- Troubleshooting DNS issues

## Post-Installation

### 1. Create Email Accounts

**Using PostfixAdmin (Recommended):**

1. Visit: `https://mail.yourdomain.com/postfixadmin`
2. Complete setup with the setup password
3. Create admin account
4. Add domains
5. Create mailboxes

**Using Command Line:**

```bash
# Generate password hash
doveadm pw -s SHA512-CRYPT

# Add to database
mysql -u root mail -e "INSERT INTO mail_users (email, password) VALUES ('user@domain.com', 'PASSWORD_HASH');"
```

### 2. Test Configuration

```bash
# Run automated tests
sudo ./test-server.sh

# Manual testing
postfix check          # Check Postfix config
doveconf -n           # Check Dovecot config
systemctl status postfix dovecot
```

### 3. Configure Firewall

```bash
# UFW (Ubuntu/Debian)
ufw allow 25/tcp      # SMTP
ufw allow 587/tcp     # Submission
ufw allow 993/tcp     # IMAPS
ufw allow 80/tcp      # HTTP
ufw allow 443/tcp     # HTTPS
ufw enable

# FirewallD (RHEL/CentOS)
firewall-cmd --add-service=smtp --permanent
firewall-cmd --add-service=smtp-submission --permanent
firewall-cmd --add-service=imaps --permanent
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --reload
```

### 4. Send Test Email

```bash
echo "Test email body" | mail -s "Test" user@example.com
```

### 5. Check Logs

```bash
tail -f /var/log/mail.log
journalctl -u postfix -f
journalctl -u dovecot -f
```

## Troubleshooting

### Services Not Starting

```bash
# Check service status
systemctl status postfix
systemctl status dovecot

# View logs
journalctl -u postfix -n 50
journalctl -u dovecot -n 50

# Test configuration
postfix check
doveconf -n | less
```

### Port 25 Blocked

Many ISPs block port 25. Solutions:
1. Use port 587 for sending
2. Contact ISP to unblock port 25
3. Use mail relay service

### SSL Certificate Errors

```bash
# Check certificates
certbot certificates

# Renew manually
certbot renew

# Check certificate files
ls -la /etc/letsencrypt/live/yourdomain.com/
```

### Authentication Failures

```bash
# Test authentication
doveadm auth test user@domain.com

# Check password hash
mysql -u root mail -e "SELECT email, password FROM mail_users WHERE email='user@domain.com';"

# Regenerate password
doveadm pw -s SHA512-CRYPT -p newpassword
```

### DNS Not Resolving

```bash
# Check DNS records
dig yourdomain.com MX
dig mail.yourdomain.com A
dig -x YOUR_SERVER_IP

# DNS propagation can take 24-48 hours
# Use: https://www.whatsmydns.net/
```

### Emails Going to Spam

Common causes:
1. Missing SPF record
2. Missing DKIM signatures
3. No reverse DNS (PTR)
4. New IP with poor reputation
5. Missing DMARC record

Test deliverability:
- https://www.mail-tester.com/
- https://mxtoolbox.com/

### Connection Refused

```bash
# Check if ports are open
netstat -tuln | grep :25
netstat -tuln | grep :587
netstat -tuln | grep :993

# Check firewall
ufw status
iptables -L

# Check if service is listening
ss -tlnp | grep postfix
ss -tlnp | grep dovecot
```

## Getting Help

- **Logs**: Always check `/var/log/mail.log` first
- **Configuration**: Review `/etc/postfix/main.cf` and `/etc/dovecot/dovecot.conf`
- **Testing**: Run `./test-server.sh` for automated diagnostics
- **Community**: Check GitHub issues

## Next Steps

After successful installation:
1. Set up email clients (see [Email Clients Guide](EMAIL_CLIENTS.md))
2. Configure backups (see [Backup Guide](BACKUP.md))
3. Set up monitoring (see [Monitoring Guide](MONITORING.md))
4. Review security (see [Security Guide](SECURITY.md))
