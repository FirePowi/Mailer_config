# Security Hardening Guide

Complete guide to securing your mail server.

## SSL/TLS Security

### Mozilla Modern Cipher Suites

Your server is pre-configured with Mozilla Modern cipher suite profile:

**Enabled Ciphers:**
```
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-RSA-AES256-GCM-SHA384
ECDHE-ECDSA-CHACHA20-POLY1305
ECDHE-RSA-CHACHA20-POLY1305
DHE-RSA-AES128-GCM-SHA256
DHE-RSA-AES256-GCM-SHA384
```

**Disabled Protocols:**
- SSLv2, SSLv3 (vulnerable)
- TLS 1.0, TLS 1.1 (deprecated)

**Only TLS 1.2 and 1.3 are allowed.**

### Security Audit

Check your SSL/TLS configuration:

```bash
sudo ./check-ssl-ciphers.sh
```

This checks:
- Protocol versions
- Cipher strength
- Certificate validity
- Security headers
- Weak cipher detection

### Update SSL Configuration

To update all services to the latest security standards:

```bash
sudo ./update-ssl-config.sh
```

This script:
- Backs up current configurations
- Updates to Mozilla Modern ciphers
- Tests configurations
- Offers to restart services

### Testing SSL/TLS

**Internal Testing:**
```bash
# Test SMTP TLS
openssl s_client -starttls smtp -connect mail.example.com:587

# Test IMAPS
openssl s_client -connect mail.example.com:993

# Test HTTPS
openssl s_client -connect mail.example.com:443
```

**External Testing:**
- **SSL Labs**: https://www.ssllabs.com/ssltest/
  - Target: A+ rating
  
- **Check TLS**: https://www.checktls.com/
  - Comprehensive mail server TLS testing

Expected Results:
- ✅ TLS 1.2, 1.3 only
- ✅ Forward Secrecy: Yes
- ✅ Strong ciphers only
- ✅ No weak protocols

## Firewall Configuration

### UFW (Ubuntu/Debian)

```bash
# Reset firewall (if needed)
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (IMPORTANT: do this first!)
ufw allow 22/tcp

# Mail server ports
ufw allow 25/tcp     # SMTP
ufw allow 587/tcp    # Submission (STARTTLS)
ufw allow 993/tcp    # IMAPS
ufw allow 995/tcp    # POP3S (optional)

# Web server (for webmail/PostfixAdmin)
ufw allow 80/tcp     # HTTP (redirect to HTTPS)
ufw allow 443/tcp    # HTTPS

# Enable firewall
ufw enable

# Check status
ufw status verbose
```

### FirewallD (RHEL/CentOS/Fedora)

```bash
# Enable firewalld
systemctl enable --now firewalld

# Add services
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=smtp
firewall-cmd --permanent --add-service=smtp-submission
firewall-cmd --permanent --add-service=imaps
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

# Or add ports directly
firewall-cmd --permanent --add-port=25/tcp
firewall-cmd --permanent --add-port=587/tcp
firewall-cmd --permanent --add-port=993/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp

# Reload
firewall-cmd --reload

# Check status
firewall-cmd --list-all
```

### iptables (Manual)

```bash
# Flush existing rules
iptables -F

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow mail ports
iptables -A INPUT -p tcp --dport 25 -j ACCEPT
iptables -A INPUT -p tcp --dport 587 -j ACCEPT
iptables -A INPUT -p tcp --dport 993 -j ACCEPT

# Allow web ports
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
```

## Fail2Ban

Protect against brute-force attacks.

### Installation

```bash
# Debian/Ubuntu
apt-get install fail2ban

# RHEL/CentOS
yum install fail2ban

# Arch
pacman -S fail2ban
```

### Configuration

Create `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = admin@example.com
sendername = Fail2Ban

[sshd]
enabled = true

[postfix]
enabled = true
port = smtp,submission
logpath = /var/log/mail.log

[dovecot]
enabled = true
port = imap,imaps,pop3,pop3s
logpath = /var/log/mail.log

[postfix-sasl]
enabled = true
port = smtp,submission,imap,imaps,pop3,pop3s
logpath = /var/log/mail.log
```

### Enable and Start

```bash
systemctl enable fail2ban
systemctl start fail2ban

# Check status
fail2ban-client status

# Check specific jail
fail2ban-client status postfix

# Unban an IP
fail2ban-client set postfix unbanip 1.2.3.4
```

## Email Authentication

### SPF (Sender Policy Framework)

Already configured in DNS. Verify:

```bash
dig example.com TXT | grep spf
```

Expected: `v=spf1 mx a ~all`

### DKIM (DomainKeys Identified Mail)

If OpenDKIM is installed:

```bash
# Generate keys
mkdir -p /etc/opendkim/keys/example.com
cd /etc/opendkim/keys/example.com
opendkim-genkey -d example.com -s default
chown -R opendkim:opendkim /etc/opendkim/keys/

# Get public key for DNS
cat /etc/opendkim/keys/example.com/default.txt
```

Add to DNS:
```
Type: TXT
Name: default._domainkey
Value: (the public key from above)
```

Test DKIM:
```bash
# Send test email
echo "Test" | mail -s "DKIM Test" check-auth@verifier.port25.com

# Check response email for DKIM results
```

### DMARC (Domain-based Message Authentication)

Already in DNS. To receive reports, monitor the email address in your DMARC record.

Upgrade policy after monitoring:
```
# Start with (monitoring only):
v=DMARC1; p=none; rua=mailto:admin@example.com

# After 2-4 weeks, upgrade to:
v=DMARC1; p=quarantine; rua=mailto:admin@example.com

# Eventually (strict):
v=DMARC1; p=reject; rua=mailto:admin@example.com
```

## Database Security

### Secure MySQL/MariaDB

```bash
# Run security script
mysql_secure_installation
```

Answer yes to:
- Set root password
- Remove anonymous users
- Disallow root login remotely
- Remove test database
- Reload privilege tables

### Restrict Database Access

Edit `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
[mysqld]
bind-address = 127.0.0.1
```

This ensures database only accepts local connections.

### Regular Backups

```bash
# Backup mail database
mysqldump -u root -p mail > mail_backup_$(date +%Y%m%d).sql

# Backup all databases
mysqldump -u root -p --all-databases > all_databases_$(date +%Y%m%d).sql
```

## File Permissions

### Restrict Postfix Configuration

```bash
chmod 640 /etc/postfix/main.cf
chmod 640 /etc/postfix/mysql-*.cf
chown root:postfix /etc/postfix/*.cf
```

### Restrict Dovecot Configuration

```bash
chmod 640 /etc/dovecot/dovecot.conf
chmod 640 /etc/dovecot/dovecot-sql.conf.ext
chown root:dovecot /etc/dovecot/*.conf*
```

### Protect Virtual Mailboxes

```bash
chown -R vmail:vmail /var/vmail
chmod 700 /var/vmail
```

## Security Headers

Already configured on webmail interfaces:

```
Strict-Transport-Security: max-age=31536000
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

Verify:
```bash
curl -I https://mail.example.com | grep -E "Strict-Transport|X-Frame|X-Content"
```

## Rate Limiting

### Postfix Rate Limiting

Add to `/etc/postfix/main.cf`:

```
# Limit SMTP clients
smtpd_client_connection_rate_limit = 10
smtpd_client_message_rate_limit = 20

# Limit errors before disconnect
smtpd_error_sleep_time = 5s
smtpd_soft_error_limit = 2
smtpd_hard_error_limit = 5
```

### Dovecot Rate Limiting

In `/etc/dovecot/dovecot.conf`:

```
protocol imap {
  mail_max_userip_connections = 10
}

protocol pop3 {
  mail_max_userip_connections = 3
}
```

## Monitoring and Logging

### Enable Detailed Logging

Postfix `/etc/postfix/main.cf`:
```
# Increase logging verbosity
debug_peer_level = 2
debug_peer_list = 127.0.0.1
```

Dovecot `/etc/dovecot/conf.d/10-logging.conf`:
```
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log
```

### Log Rotation

Ensure logrotate is configured for `/etc/logrotate.d/mail`:

```
/var/log/mail.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 syslog adm
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

### Monitor Failed Login Attempts

```bash
# Postfix authentication failures
grep "authentication failed" /var/log/mail.log

# Dovecot failed logins
grep "auth failed" /var/log/mail.log

# Count by IP
grep "authentication failed" /var/log/mail.log | awk '{print $6}' | sort | uniq -c | sort -nr
```

## Regular Maintenance

### Weekly Tasks

```bash
# Check for unauthorized root access
aureport --auth | grep root

# Review mail logs for anomalies
tail -1000 /var/log/mail.log | grep -i error

# Check disk usage
df -h
du -sh /var/vmail

# Check mail queue
mailq

# Update packages
apt-get update && apt-get upgrade  # Debian/Ubuntu
yum update                         # RHEL/CentOS
```

### Monthly Tasks

```bash
# Test SSL certificates
./check-ssl-ciphers.sh

# Test mail server
./test-server.sh

# Review fail2ban blocks
fail2ban-client status

# Check for CVEs
apt-cache show postfix dovecot | grep CVE
```

### Security Checklist

- [ ] Firewall configured and enabled
- [ ] Fail2Ban installed and active
- [ ] SSL certificates valid and auto-renewing
- [ ] Strong cipher suites configured
- [ ] Database access restricted to localhost
- [ ] File permissions correctly set
- [ ] SPF, DKIM, DMARC configured
- [ ] Rate limiting enabled
- [ ] Logs being rotated
- [ ] Regular backups automated
- [ ] Monitoring in place

## External Security Scans

### Port Scanning

Test your server from external perspective:

```bash
nmap -sV -p 25,587,993,80,443 your-server-ip
```

Expected: Only intended ports should be open.

### Vulnerability Scanning

- **Nessus**: https://www.tenable.com/products/nessus
- **OpenVAS**: https://www.openvas.org/
- **Qualys**: https://www.qualys.com/

### Blacklist Checking

Check if your server's IP is blacklisted:

- **MX Toolbox**: https://mxtoolbox.com/blacklists.aspx
- **MultiRBL**: http://multirbl.valli.org/
- **Spamhaus**: https://www.spamhaus.org/lookup/

## Incident Response

### If Compromised

1. **Immediate Actions:**
   ```bash
   # Stop mail services
   systemctl stop postfix dovecot
   
   # Block outgoing SMTP
   iptables -A OUTPUT -p tcp --dport 25 -j DROP
   
   # Disconnect from network (if severe)
   ifconfig eth0 down
   ```

2. **Investigation:**
   ```bash
   # Check recent connections
   last | head -20
   
   # Check running processes
   ps auxf | less
   
   # Check mail queue for spam
   mailq
   
   # Review logs
   tail -1000 /var/log/mail.log
   grep -i "relay" /var/log/mail.log
   ```

3. **Recovery:**
   - Change all passwords
   - Update all software
   - Review configurations
   - Re-check security settings
   - Monitor closely after restart

4. **Prevention:**
   - Implement lessons learned
   - Add additional monitoring
   - Review access controls
   - Document incident

## Security Resources

- **Mozilla SSL Config Generator**: https://ssl-config.mozilla.org/
- **OWASP**: https://owasp.org/
- **SANS Internet Storm Center**: https://isc.sans.edu/
- **Postfix Security**: http://www.postfix.org/SASL_README.html
- **Dovecot Security**: https://doc.dovecot.org/configuration_manual/howto/
