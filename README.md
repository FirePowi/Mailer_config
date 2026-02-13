# Mail Server Installer

**Zero-knowledge setup for a complete, production-ready mail server. No DNS or Linux expertise required!**

![Version](https://img.shields.io/badge/version-2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

## ✨ Why Use This?

- **🎯 Zero-Knowledge Setup**: Interactive DNS assistant - no DNS expertise required
- **🏗️ Modular & Clean**: 70-line orchestrator + focused libraries (was 3,711-line monolith)
- **🧪 Automated Testing**: Built-in test suite validates everything
- **🔒 Security First**: Mozilla Modern ciphers, TLS 1.2+, Let's Encrypt SSL
- **📧 Complete Stack**: Postfix + Dovecot + MySQL + PostfixAdmin + Webmail
- **⚡ Auto-Config**: Outlook Autodiscover + Thunderbird Autoconfig
- **🌍 Multi-Distro**: Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, openSUSE

## 🚀 Quick Start

```bash
git clone gh:FirePowi/Mailer_config
cd Mailer_config/.specify/scripts/bash
chmod +x install.sh
sudo ./install.sh
```

**That's it!** The installer will:
1. Detect your system automatically
2. Ask simple questions interactively
3. **Guide you through DNS setup** (step-by-step, no prior knowledge needed)
4. Install and configure everything
5. Generate SSL certificates
6. Test your server

## 📖 Documentation

Everything is documented in detail:

- **[Installation Guide](Documentation/INSTALLATION.md)** - Complete walkthrough, component selection, requirements
- **[DNS Configuration](Documentation/DNS.md)** - Provider-specific guides (Cloudflare, GoDaddy, Namecheap, Google, Route53)
- **[Testing Guide](Documentation/TESTING.md)** - How to use the automated test suite
- **[Security Hardening](Documentation/SECURITY.md)** - SSL/TLS, firewalls, Fail2Ban, monitoring
- **[Troubleshooting](Documentation/TROUBLESHOOTING.md)** - Common issues and solutions

## 🧪 Testing Your Server

Automated test suite validates your entire configuration:

```bash
sudo ./scripts/test-server.sh

# Or test specific components:
sudo ./scripts/test-server.sh --services  # Test Postfix, Dovecot, MySQL
sudo ./scripts/test-server.sh --network   # Test ports and connectivity
sudo ./scripts/test-server.sh --ssl       # Validate SSL certificates
sudo ./scripts/test-server.sh --dns       # Check DNS records
sudo ./scripts/test-server.sh --mail      # Test mail flow
```

See [Documentation/TESTING.md](Documentation/TESTING.md) for details.

## 📦 What's Included

**Core Services** (required):
- Postfix - SMTP server
- Dovecot - IMAP/POP3 server  
- MySQL/MariaDB - Database
- PostfixAdmin - Web management

**Optional Components**:
- SpamAssassin - Spam filtering
- ClamAV - Antivirus scanning
- OpenDKIM - Email authentication
- Fail2Ban - Brute force protection
- Webmail - SnappyMail, Roundcube, or SOGo

**Security Features**:
- Let's Encrypt SSL/TLS (auto-renewal)
- Mozilla Modern cipher suites
- TLS 1.2+ only (no weak protocols)
- Strong encryption (ECDHE, AES-GCM, ChaCha20)

## 📋 Requirements

- **OS**: Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, openSUSE
- **RAM**: 2 GB minimum (4 GB recommended)
- **Disk**: 20 GB minimum
- **Network**: Public IP, domain name
- **Access**: Root/sudo privileges

**No Linux or DNS knowledge required!** The installer guides you through everything.

## 🏗️ Code Structure

Modular architecture for easy maintenance:

```
install.sh              # Main orchestrator (70 lines)
lib/
├── ui.sh              # User interface & colors
├── system.sh          # Distribution detection
├── packages.sh        # Package management
├── dns.sh             # DNS configuration helper (5 providers)
├── input.sh           # User input collection
└── config.sh          # Configuration variables
scripts/
├── test-server.sh          # Automated testing suite
├── check-ssl-ciphers.sh    # SSL security audit
├── update-ssl-config.sh    # SSL configuration updater
└── [other utilities]       # Additional helper scripts
Documentation/              # Detailed guides
```

## 🤝 Contributing

Contributions welcome! Please fork, create a feature branch, test thoroughly, and submit a PR.

## 📄 License

MIT License - See [LICENSE](LICENSE) file.

## 📞 Support

- **Issues**: https://github.com/FirePowi/Mailer_config/issues
- **Discussions**: https://github.com/FirePowi/Mailer_config/discussions

---

**Made with ❤️ for the open-source community**
