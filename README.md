# Mail Server Installer

**Interactive installation script for a complete, production-ready mail server with modern security features.**

![Version](https://img.shields.io/badge/version-2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

## 🚀 Features

### Core Mail Services
- **Postfix** - Modern, secure SMTP server
- **Dovecot** - High-performance IMAP/POP3 server with virtual users
- **MySQL/MariaDB** - Database backend for virtual mail domains and users
- **PostfixAdmin** - Web interface for managing domains, mailboxes, and aliases

### Security Features
- ✅ **Mozilla Modern Cipher Suites** - TLS 1.2+ only, no weak ciphers
- ✅ **SSL/TLS Certificates** - Automated Let's Encrypt integration
- ✅ **Strong Encryption** - ECDHE, AES-GCM, ChaCha20-Poly1305
- ✅ **Security Headers** - HSTS, X-Frame-Options, CSP
- ✅ **Forward Secrecy** - DHE/ECDHE key exchange
- ✅ **No Weak Protocols** - SSLv2, SSLv3, TLS 1.0/1.1 disabled
- ✅ **Explicit Cipher Exclusions** - Blocks 3DES, RC4, MD5, CBC mode

### Anti-Spam & Anti-Virus (Optional)
- **SpamAssassin** - Content-based spam filtering
- **ClamAV** - Virus scanning for emails
- **Policyd-SPF** - SPF policy verification
- **DKIM** - DomainKeys Identified Mail signing

### Webmail Clients (Optional)
- **SnappyMail** - Modern, fast, lightweight webmail (no database required)
- **Roundcube** - Feature-rich, plugin-extensible webmail
- **SOGo** - Complete groupware with Calendar (CalDAV), Contacts (CardDAV), and ActiveSync

### Email Client Autoconfiguration
- **Microsoft Autodiscover** - Automatic setup for Outlook
- **Mozilla Autoconfig** - Automatic setup for Thunderbird
- **Universal Support** - Works with Apple Mail and other modern clients

### Web Server Support
- **Nginx** - High-performance, low-resource web server
- **Apache** - Traditional, widely-supported web server
- **Auto-detection** - Automatically detects existing installations
- **Flexible Choice** - User can choose preferred web server

### SSL/TLS Security Tools
- **check-ssl-ciphers.sh** - Comprehensive security audit script
  - Scans Postfix, Dovecot, Nginx, Apache configurations
  - Tests live connections (SMTP, IMAP, HTTPS)
  - Detects 20+ weak cipher patterns
  - Color-coded vulnerability reports
  
- **update-ssl-config.sh** - Automated security hardening
  - Updates all services to Mozilla Modern ciphers
  - Creates timestamped backups
  - Tests configurations before applying
  - Safe, idempotent operations

## 📋 Requirements

### Supported Operating Systems
- ✅ **Debian** 10, 11, 12 (Buster, Bullseye, Bookworm)
- ✅ **Ubuntu** 18.04, 20.04, 22.04, 24.04 LTS
- ✅ **RedHat Enterprise Linux** 7, 8, 9
- ✅ **CentOS** 7, 8, 9 (Stream)
- ✅ **Fedora** 35+
- ✅ **Arch Linux** (latest)
- ✅ Derivatives of the above distributions

### System Requirements
- **Root access** or sudo privileges
- **2 GB RAM minimum** (4 GB recommended)
- **20 GB disk space** (more for email storage)
- **Static IP address** (required for mail server)
- **Valid domain name(s)** - We'll help you configure DNS!
- **Open ports**: 25, 143, 587, 993, 995 (mail), 80, 443 (web)

### What You Need to Know
**Nothing!** This installer is designed for users with zero mail server experience:
- ✅ **No DNS knowledge required** - Interactive DNS setup guide included
- ✅ **No Linux expertise needed** - We detect your system automatically
- ✅ **No security configuration** - Mozilla Modern cipher suites pre-configured
- ✅ **No manual setup** - Everything is automated with helpful prompts

## 🎯 Quick Start

### 1. Download the Installer

```bash
git clone gh:FirePowi/Mailer_config
cd Mailer_config/.specify/scripts/bash
chmod +x install.sh
```

### 2. Run the Installer

```bash
sudo ./install.sh
```

The script will:
1. ✅ Detect your Linux distribution automatically
2. ✅ Check system requirements
3. ✅ Ask simple questions interactively
4. ✅ **Guide you through DNS setup step-by-step** (no prior knowledge needed!)
5. ✅ Install and configure all components
6. ✅ Generate SSL certificates automatically
7. ✅ Start and enable services
8. ✅ Display credentials and detailed next steps

### 3. Follow the Interactive Prompts

The installer will ask you:
- **Primary domain** (e.g., example.com)
- **Additional domains** (optional, press Enter to skip)
- **Hostname** (e.g., mail.example.com)
- **Admin email address**
- **Optional components** (SpamAssassin, ClamAV, etc.)
- **Webmail client** (SnappyMail, Roundcube, SOGo, or none)
- **Web server** (Nginx or Apache, or auto-detect)

**Then we guide you through DNS setup!** No need to know anything about DNS - we provide:
- ✅ Step-by-step instructions for popular DNS providers (Cloudflare, GoDaddy, Namecheap, Google)
- ✅ Copy-paste ready DNS records
- ✅ Visual guides for each provider
- ✅ Explanation of what each record does

## 📖 Documentation

### Installation Guide
See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for:
- Detailed installation walkthrough
- Component selection guide
- **DNS setup for complete beginners** (step-by-step with screenshots)
- SSL/TLS security features
- Post-installation configuration
- Troubleshooting tips

### Code Structure
The installer uses a **modular architecture** for easy maintenance and understanding:

```
install.sh              # Main installer (orchestration)
lib/
├── config.sh          # Configuration variables
├── ui.sh              # User interface and colors
├── system.sh          # Distribution detection
├── packages.sh        # Package management
├── dns.sh             # DNS configuration helper
└── input.sh           # User input collection

# Legacy monolithic file (being phased out)
install-mail-server.sh  # Contains postfix, dovecot, webmail, ssl configs
```

**Benefits of modular structure:**
- ✅ Easy to understand (small, focused files)
- ✅ Easy to maintain (change one module without affecting others)
- ✅ Easy to extend (add new features in new modules)
- ✅ Easy to test (test individual modules)

### Webmail Features
See [WEBMAIL_FEATURES.md](WEBMAIL_FEATURES.md) for:
- Webmail client comparison
- Installation requirements
- Configuration details
- Feature matrices

## 🔒 Security Features

### SSL/TLS Configuration

All components are configured with **Mozilla Modern** cipher suites:

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

**Explicitly excluded:**
- ❌ aNULL, eNULL (no encryption)
- ❌ EXPORT (export-grade weakness)
- ❌ DES, 3DES (broken/deprecated)
- ❌ MD5 (collision attacks)
- ❌ RC2, RC4 (broken stream ciphers)
- ❌ CBC mode (BEAST/Lucky13 vulnerabilities)
- ❌ All SSLv2, SSLv3, TLS 1.0, TLS 1.1

### Security Audit

Check your configuration anytime:

```bash
sudo ./check-ssl-ciphers.sh
```

Expected results:
- ✅ **SSL Labs A+ rating**
- ✅ **TLS 1.2 and 1.3 only**
- ✅ **Forward Secrecy: Yes**
- ✅ **Weak Ciphers: None**

### Update Security Configuration

Upgrade existing installations:

```bash
sudo ./update-ssl-config.sh
```

This script:
- Creates timestamped backups
- Updates all SSL/TLS configurations
- Tests configs before applying
- Prompts to restart services

## 🌐 Email Client Autoconfiguration

The installer automatically sets up:

### Thunderbird / K-9 Mail (Mozilla Autoconfig)
- Autodiscovery URL: `http://autoconfig.yourdomain.com/mail/config-v1.1.xml`
- Clients automatically detect settings

### Outlook / Apple Mail (Microsoft Autodiscover)
- Autodiscovery URL: `http://autodiscover.yourdomain.com/autodiscover/autodiscover.xml`
- Full Outlook autoconfiguration support

### Required DNS Records
```dns
autoconfig.example.com.     IN  A  <YOUR_SERVER_IP>
autodiscover.example.com.   IN  A  <YOUR_SERVER_IP>
```

**No manual setup needed!** Users just enter email and password.

## 🛠️ Post-Installation

### Create Your First Email Account

Using PostfixAdmin (recommended):
1. Visit `https://mail.yourdomain.com/postfixadmin`
2. Complete setup with the provided setup password
3. Create admin user
4. Create domains and mailboxes

Using command line:
```bash
doveadm pw -s SHA512-CRYPT -p your_password
# Copy the hash and use it in the SQL INSERT
```

### Test Your Server

```bash
# Test SMTP
telnet mail.yourdomain.com 25

# Test IMAPS
openssl s_client -connect mail.yourdomain.com:993

# Check Postfix config
postfix check
postconf -n

# Check Dovecot config
doveconf -n
```

### Monitor Logs

```bash
# Follow mail logs
tail -f /var/log/mail.log

# Postfix logs
journalctl -u postfix -f

# Dovecot logs
journalctl -u dovecot -f
```

## 🔥 Firewall Configuration

```bash
# Mail server ports
ufw allow 25/tcp     # SMTP
ufw allow 143/tcp    # IMAP
ufw allow 587/tcp    # Submission (STARTTLS)
ufw allow 993/tcp    # IMAPS
ufw allow 995/tcp    # POP3S

# Web server ports (if using webmail)
ufw allow 80/tcp     # HTTP (Let's Encrypt)
ufw allow 443/tcp    # HTTPS (webmail)

# Enable firewall
ufw enable
```

## 📊 Component Overview

| Component | Purpose | Required | Notes |
|-----------|---------|----------|-------|
| Postfix | SMTP server | ✅ Yes | Mail delivery |
| Dovecot | IMAP/POP3 server | ✅ Yes | Mail retrieval |
| MySQL/MariaDB | Database | ✅ Yes | Virtual users |
| PostfixAdmin | Web admin panel | ⚠️ Recommended | Mailbox management |
| SpamAssassin | Spam filtering | ⚙️ Optional | Resource intensive |
| ClamAV | Virus scanning | ⚙️ Optional | High memory usage |
| Policyd-SPF | SPF verification | ⚙️ Optional | Recommended |
| DKIM | Email signing | ⚙️ Optional | Improves deliverability |
| Webmail | Browser email | ⚙️ Optional | User convenience |
| Nginx/Apache | Web server | 📧 Webmail only | For PostfixAdmin + webmail |

## 🧪 Testing Email Delivery

### Send Test Email

```bash
echo "Test email body" | mail -s "Test Subject" user@example.com
```

### Check Mail Queue

```bash
mailq                 # View queue
postqueue -f          # Flush queue
postqueue -p          # Print queue
```

### Test Authentication

```bash
doveadm auth test user@yourdomain.com
```

### External Testing Tools

- **SSL/TLS Test**: https://www.ssllabs.com/ssltest/
- **Email Security**: https://www.checktls.com/
- **MX Toolbox**: https://mxtoolbox.com/
- **Mail Tester**: https://www.mail-tester.com/

## 🐛 Troubleshooting

### Common Issues

**Port 25 blocked by ISP?**
- Use port 587 (submission) instead
- Consider using a mail relay

**Certificate errors?**
- Ensure DNS points to your server
- Wait for DNS propagation (up to 48 hours)
- Check Let's Encrypt rate limits

**Connection refused?**
- Check firewall rules: `ufw status`
- Verify services running: `systemctl status postfix dovecot`
- Check listening ports: `netstat -tlnp`

**Authentication failures?**
- Test with: `doveadm auth test user@domain.com`
- Check password hash in database
- Review `/var/log/mail.log`

**Emails not received?**
- Check MX records: `dig MX yourdomain.com`
- Verify reverse DNS (PTR record)
- Check spam folder
- Review sender reputation

### Configuration Files

All configuration files are heavily commented:

```
/etc/postfix/main.cf           # Postfix main configuration
/etc/postfix/master.cf         # Postfix service configuration
/etc/dovecot/dovecot.conf      # Dovecot main configuration
/etc/dovecot/dovecot-sql.conf.ext  # Dovecot SQL queries
```

### Useful Commands

```bash
# Reload configurations
postfix reload
systemctl reload dovecot

# Check configuration syntax
postfix check
doveconf -n

# View real-time logs
tail -f /var/log/mail.log

# Check disk usage
du -sh /var/vmail/*

# List all virtual mailboxes
find /var/vmail -type d -name cur
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Postfix** - http://www.postfix.org/
- **Dovecot** - https://www.dovecot.org/
- **PostfixAdmin** - https://postfixadmin.github.io/postfixadmin/
- **SnappyMail** - https://snappymail.eu/
- **Roundcube** - https://roundcube.net/
- **SOGo** - https://www.sogo.nu/
- **Mozilla SSL Configuration Generator** - https://ssl-config.mozilla.org/

## 📞 Support

- **Documentation**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Issues**: https://github.com/FirePowi/Mailer_config/issues
- **Discussions**: https://github.com/FirePowi/Mailer_config/discussions

## ⚠️ Disclaimer

This script is provided as-is, without warranty. Always:
- Test in a non-production environment first
- Keep backups of your data
- Review generated configurations
- Follow security best practices
- Monitor your server regularly

---

**Made with ❤️ for the open-source community**
