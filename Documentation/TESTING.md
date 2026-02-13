# Mail Server Testing Suite

This script automatically tests your mail server configuration and connectivity.

## What It Tests

### 1. Service Status
- ✓ Postfix SMTP server
- ✓ Dovecot IMAP/POP3 server
- ✓ MySQL/MariaDB database
- ✓ Web server (Nginx/Apache)

### 2. Network Connectivity
- ✓ SMTP ports (25, 587, 465)
- ✓ IMAP ports (143, 993)
- ✓ POP3 ports (110, 995)
- ✓ HTTP/HTTPS ports (80, 443)

### 3. SSL/TLS Configuration
- ✓ Certificate validity
- ✓ Cipher strength
- ✓ Protocol versions
- ✓ Certificate chain

### 4. DNS Records
- ✓ A record
- ✓ MX record
- ✓ SPF record
- ✓ DMARC record
- ✓ Reverse DNS (PTR)

### 5. Mail Flow
- ✓ SMTP connection test
- ✓ Authentication test
- ✓ TLS/STARTTLS test

## Usage

```bash
sudo ./test-server.sh
```

## Interactive Mode

The script will:
1. Test each component automatically
2. Display results with color coding (green=pass, red=fail, yellow=warning)
3. Provide specific recommendations for failures
4. Generate a summary report

## Command Line Options

```bash
# Test specific components
sudo ./test-server.sh --services    # Only test services
sudo ./test-server.sh --network     # Only test network
sudo ./test-server.sh --ssl         # Only test SSL/TLS
sudo ./test-server.sh --dns         # Only test DNS
sudo ./test-server.sh --mail        # Only test mail flow

# Verbose output
sudo ./test-server.sh --verbose     # Show detailed output

# Non-interactive mode
sudo ./test-server.sh --quiet       # Minimal output, exit code only

# Generate report
sudo ./test-server.sh --report report.txt  # Save results to file
```

## Exit Codes

- `0` - All tests passed
- `1` - Some tests failed (warnings)
- `2` - Critical tests failed (requires attention)
- `3` - Script error

## What To Do If Tests Fail

The script provides specific guidance for each failure. Common issues:

### Service Not Running
```bash
# Check service status
systemctl status postfix
systemctl status dovecot

# Restart service
systemctl restart postfix
systemctl restart dovecot
```

### Port Not Open
```bash
# Check firewall
ufw status

# Open required ports
ufw allow 25/tcp    # SMTP
ufw allow 587/tcp   # Submission
ufw allow 993/tcp   # IMAPS
```

### SSL Certificate Issues
```bash
# Check certificates
certbot certificates

# Renew certificates
certbot renew
```

### DNS Problems
Wait for DNS propagation (can take up to 48 hours) or verify records at your DNS provider.

## Automated Testing

You can run this script in cron for regular monitoring:

```bash
# Add to crontab (test daily at 2 AM)
0 2 * * * /path/to/test-server.sh --quiet --report /var/log/mail-server-test.log
```

## External Testing Tools

After running this script, you can also use these external tools:

- **MX Toolbox**: https://mxtoolbox.com/
- **SSL Labs**: https://www.ssllabs.com/ssltest/
- **Mail Tester**: https://www.mail-tester.com/
- **Check TLS**: https://www.checktls.com/
