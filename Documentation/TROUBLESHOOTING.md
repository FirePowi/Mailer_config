# Troubleshooting Guide

Common issues and solutions for your mail server.

## Service Issues

### Postfix Won't Start

**Symptom:** `systemctl start postfix` fails

**Diagnosis:**
```bash
# Check syntax
postfix check

# Check full status
systemctl status postfix -l

# View recent logs
journalctl -u postfix -n 50
```

**Common Causes:**

1. **Configuration Syntax Error**
   ```bash
   # Error: main.cf syntax error
   # Fix: Check the error message
   postfix check
   # Edit the problematic line
   nano /etc/postfix/main.cf
   ```

2. **Port Already in Use**
   ```bash
   # Check what's using port 25
   netstat -tulpn | grep :25
   # Or
   ss -tulpn | grep :25
   
   # If another MTA is running (like sendmail):
   systemctl stop sendmail
   systemctl disable sendmail
   ```

3. **Missing Directories**
   ```bash
   # Create required directories
   mkdir -p /var/spool/postfix
   chown -R postfix:postfix /var/spool/postfix
   ```

### Dovecot Won't Start

**Symptom:** `systemctl start dovecot` fails

**Diagnosis:**
```bash
# Check configuration
doveconf -n

# Check for errors
dovecot -F

# View logs
journalctl -u dovecot -n 50
```

**Common Causes:**

1. **Configuration Error**
   ```bash
   # Test config
   doveconf -n
   
   # If error, check the file mentioned
   nano /etc/dovecot/dovecot.conf
   ```

2. **SSL Certificate Issues**
   ```bash
   # Verify certificate files exist
   ls -la /etc/letsencrypt/live/mail.example.com/
   
   # Check permissions
   chmod 644 /etc/letsencrypt/live/mail.example.com/fullchain.pem
   chmod 644 /etc/letsencrypt/live/mail.example.com/privkey.pem
   ```

3. **Port Conflict**
   ```bash
   # Check ports 993, 995
   netstat -tulpn | grep -E ':993|:995'
   ```

### MySQL/MariaDB Issues

**Symptom:** Database connection errors

**Diagnosis:**
```bash
# Check if MySQL is running
systemctl status mysql
# Or mariadb on some systems
systemctl status mariadb

# Test connection
mysql -u root -p
```

**Common Fixes:**

1. **Service Not Running**
   ```bash
   systemctl start mysql
   systemctl enable mysql
   ```

2. **Wrong Password in Config**
   ```bash
   # Test the password
   mysql -u mailuser -p mail
   
   # If it doesn't work, reset it:
   mysql -u root -p
   ```
   
   Then in MySQL:
   ```sql
   ALTER USER 'mailuser'@'localhost' IDENTIFIED BY 'new_password';
   FLUSH PRIVILEGES;
   ```
   
   Update config files:
   ```bash
   nano /etc/postfix/mysql-virtual-mailbox-domains.cf
   nano /etc/postfix/mysql-virtual-mailbox-maps.cf
   nano /etc/dovecot/dovecot-sql.conf.ext
   ```

3. **Database Missing**
   ```bash
   mysql -u root -p -e "SHOW DATABASES;"
   
   # If 'mail' database is missing:
   mysql -u root -p
   ```
   
   ```sql
   CREATE DATABASE mail;
   GRANT ALL ON mail.* TO 'mailuser'@'localhost';
   ```

## Connection Issues

### Cannot Connect to SMTP

**Symptom:** Mail client shows "Connection refused" or timeout on port 587

**Check Firewall:**
```bash
# UFW
ufw status | grep 587

# If blocked:
ufw allow 587/tcp

# FirewallD
firewall-cmd --list-ports | grep 587

# If blocked:
firewall-cmd --permanent --add-port=587/tcp
firewall-cmd --reload
```

**Check Service:**
```bash
# Is Postfix listening?
netstat -tulpn | grep :587

# If not, check main.cf for:
# submission inet n       -       n       -       -       smtpd
postconf | grep submission
```

**Check from External:**
```bash
telnet your-server-ip 587
# Should see: 220 mail.example.com ESMTP Postfix

# If timeout: Firewall or ISP blocking port
# If connection refused: Postfix not listening
# If connected: Success!
```

### Cannot Connect to IMAP

**Symptom:** Mail client cannot retrieve email on port 993

**Check Firewall:**
```bash
ufw status | grep 993
# If needed:
ufw allow 993/tcp
```

**Check Dovecot:**
```bash
# Is it listening?
netstat -tulpn | grep :993

# Test locally
openssl s_client -connect localhost:993

# If working, you should see certificate info
```

**Check Logs:**
```bash
tail -f /var/log/mail.log
# Try to connect while watching logs
```

### ISP Blocks Port 25

**Symptom:** Can send to Gmail/Yahoo but they cannot reply

Many ISPs block outbound port 25 to prevent spam.

**Solution: Use Smart Host (Relay)**

Edit `/etc/postfix/main.cf`:
```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

Create `/etc/postfix/sasl_passwd`:
```
[smtp.gmail.com]:587 your-email@gmail.com:your-app-password
```

Hash it:
```bash
postmap /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd*
systemctl reload postfix
```

## SSL/TLS Issues

### Certificate Errors

**Symptom:** "Certificate not trusted" or "Name mismatch"

**Check Certificate:**
```bash
# View certificate
openssl s_client -connect mail.example.com:993 | openssl x509 -text

# Check expiry
openssl s_client -connect mail.example.com:993 | openssl x509 -noout -dates
```

**Common Issues:**

1. **Certificate Expired**
   ```bash
   # Renew with certbot
   certbot renew
   
   # Or force renewal
   certbot renew --force-renewal
   
   # Reload services
   systemctl reload postfix dovecot nginx
   ```

2. **Wrong Certificate File**
   ```bash
   # Check Dovecot config
   grep ssl_cert /etc/dovecot/conf.d/10-ssl.conf
   
   # Should point to Let's Encrypt:
   ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem
   ssl_key = </etc/letsencrypt/live/mail.example.com/privkey.pem
   ```

3. **Hostname Mismatch**
   ```bash
   # Certificate must match the hostname you're connecting to
   # If you connect to "mail.example.com", certificate must be for "mail.example.com"
   
   # Check what's in certificate:
   openssl x509 -in /etc/letsencrypt/live/mail.example.com/cert.pem -text | grep "DNS:"
   ```

### STARTTLS Failures

**Symptom:** Cannot send email with STARTTLS on port 587

**Test STARTTLS:**
```bash
openssl s_client -starttls smtp -connect mail.example.com:587

# Should see: 250-STARTTLS
```

**Fix Postfix:**

Check `/etc/postfix/master.cf`:
```
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
```

And `/etc/postfix/main.cf`:
```
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.example.com/privkey.pem
smtpd_tls_security_level=may
```

Reload:
```bash
systemctl reload postfix
```

## Email Delivery Issues

### Emails Not Arriving

**Check Mail Queue:**
```bash
mailq
# Or
postqueue -p

# If messages are stuck, check why:
tail -100 /var/log/mail.log | grep DEFERRED
```

**Common Causes:**

1. **DNS Issues**
   ```bash
   # Can Postfix resolve domains?
   host gmail.com
   
   # If it fails, check /etc/resolv.conf
   cat /etc/resolv.conf
   # Should have: nameserver 8.8.8.8 or similar
   ```

2. **Blacklisted IP**
   ```bash
   # Check if your server IP is blacklisted
   # Use: https://mxtoolbox.com/blacklists.aspx
   
   # View queue for specific errors
   postcat -vq [message-id]
   ```

3. **Spam Filtering at Destination**
   - Check SPF, DKIM, DMARC configured correctly
   - Ensure reverse DNS is set
   - Check sender reputation

**Force Queue Processing:**
```bash
postqueue -f
```

### Can Send but Not Receive

**Check MX Records:**
```bash
dig example.com MX

# Should return:
# example.com. 3600 IN MX 10 mail.example.com.
```

**Check Firewall Allows Port 25:**
```bash
ufw status | grep 25
netstat -tulpn | grep :25
```

**Test from External:**
```bash
# From another server/computer:
telnet your-server-ip 25
# Should connect and show: 220 mail.example.com ESMTP Postfix
```

**Check Postfix is Accepting Mail:**
```bash
postconf | grep inet_interfaces
# Should be: inet_interfaces = all
# NOT: inet_interfaces = localhost
```

### Emails Going to Spam

**Run Email Tests:**
- Send test to: check-auth@verifier.port25.com
- Check: https://www.mail-tester.com/

**Common Issues:**

1. **Missing SPF**
   ```bash
   dig example.com TXT | grep spf
   # Should see: v=spf1 mx a ~all
   ```

2. **Missing DKIM**
   ```bash
   dig default._domainkey.example.com TXT
   # Should return your public key
   ```

3. **No Reverse DNS**
   ```bash
   dig -x your-server-ip
   # Should return: mail.example.com
   ```

4. **Wrong DMARC Policy**
   ```bash
   dig _dmarc.example.com TXT
   # Should see: v=DMARC1; p=quarantine...
   ```

## Authentication Issues

### Cannot Login to Email

**Test Authentication:**
```bash
# Test locally
doveadm auth test user@example.com password123
```

**Check User Exists in Database:**
```bash
mysql -u root -p mail -e "SELECT * FROM virtual_users WHERE email='user@example.com';"
```

**Check Password:**
```bash
# In database, password should be a hash like: {SHA512-CRYPT}$6$...
# If it's plain text, it won't work

# To reset password:
mysql -u root -p mail
```

```sql
UPDATE virtual_users 
SET password = ENCRYPT('newpassword', CONCAT('$6$', SUBSTRING(SHA(RAND()), -16))) 
WHERE email = 'user@example.com';
```

**Check Dovecot SQL Config:**
```bash
cat /etc/dovecot/dovecot-sql.conf.ext | grep -v "^#" | grep -v "^$"

# Ensure:
# - driver = mysql
# - connect line has correct password
# - password_query is correct
```

**Test with Telnet:**
```bash
# Generate auth string
echo -ne "\0user@example.com\0password123" | base64

# Test
telnet localhost 587
EHLO test
AUTH PLAIN [paste-base64-string-here]

# Should see: 235 2.7.0 Authentication successful
```

### SASL Authentication Failures

**Check Logs:**
```bash
grep "authentication failed" /var/log/mail.log
```

**Check SASL is Enabled:**
```bash
postconf | grep smtpd_sasl
```

Should have:
```
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
```

**Check Dovecot Auth Socket:**
```bash
ls -la /var/spool/postfix/private/auth

# Should exist and be a socket
# If not:
```

In `/etc/dovecot/conf.d/10-master.conf`:
```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

Restart:
```bash
systemctl restart dovecot postfix
```

## Performance Issues

### High Load / Slow Performance

**Check System Resources:**
```bash
# CPU usage
top

# Memory
free -h

# Disk I/O
iostat -x 1

# Disk space
df -h
```

**Check Mail Queue:**
```bash
mailq | tail -1
# If thousands of messages, could be spam attack or delivery issue
```

**Check Logs for Errors:**
```bash
tail -1000 /var/log/mail.log | grep -i error
```

**Optimize Database:**
```bash
mysql -u root -p mail -e "OPTIMIZE TABLE virtual_users, virtual_domains;"
```

### Disk Space Issues

**Find Large Files:**
```bash
# Check mailbox sizes
du -sh /var/vmail/*

# Find largest mailboxes
du -sh /var/vmail/*/* | sort -hr | head -20

# Check log size
du -sh /var/log/mail*
```

**Clean Up:**
```bash
# Clean old logs
journalctl --vacuum-time=7d

# Remove old mail (be careful!)
# This removes email older than 365 days:
find /var/vmail -type f -mtime +365 -delete

# Clean mail queue (if needed)
postsuper -d ALL deferred
```

## Update/Upgrade Issues

### After Upgrade, Mail Not Working

**Check Service Status:**
```bash
systemctl status postfix dovecot mysql
```

**Check Config Conflicts:**
```bash
# Look for .dpkg-old or .rpmnew files
find /etc/postfix /etc/dovecot -name "*.dpkg-*" -o -name "*.rpmnew"

# If found, compare:
diff /etc/postfix/main.cf /etc/postfix/main.cf.dpkg-old
```

**Re-test Configuration:**
```bash
postfix check
doveconf -n
```

**Check Logs:**
```bash
journalctl -u postfix -u dovecot --since "1 hour ago"
```

## Getting Help

If you're still stuck:

1. **Run the test script:**
   ```bash
   sudo ./test-server.sh --verbose
   ```

2. **Check documentation:**
   - [Installation Guide](INSTALLATION.md)
   - [DNS Configuration](DNS.md)
   - [Security Guide](SECURITY.md)

3. **Gather diagnostic info:**
   ```bash
   # System info
   uname -a
   cat /etc/os-release
   
   # Service status
   systemctl status postfix dovecot mysql
   
   # Recent logs
   tail -100 /var/log/mail.log
   
   # Configuration (sanitized)
   postconf -n | grep -v "password"
   doveconf -n | grep -v "password"
   ```

4. **Community resources:**
   - Postfix: http://www.postfix.org/docs.html
   - Dovecot: https://doc.dovecot.org/
   - Stack Exchange: https://serverfault.com/

5. **Check server from external tools:**
   - https://mxtoolbox.com/
   - https://www.mail-tester.com/
   - https://www.checktls.com/

## Quick Reference

### Restart Services
```bash
systemctl restart postfix dovecot
```

### Check Logs
```bash
tail -f /var/log/mail.log
```

### Check Queue
```bash
mailq
```

### Test Connection
```bash
telnet localhost 25
openssl s_client -connect localhost:993
```

### Test Authentication
```bash
doveadm auth test user@example.com password
```

### Check DNS
```bash
dig example.com MX
dig example.com TXT
dig -x YOUR_IP
```
