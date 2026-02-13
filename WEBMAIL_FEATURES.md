# Webmail Client Installation Guide

## Overview

The Interactive Mail Server Installer now includes support for **three modern webmail clients**:

1. **SnappyMail** (Recommended) - Fast, modern, file-based
2. **Roundcube** - Feature-rich, mature, extensible
3. **SOGo** - Full groupware suite with calendar and ActiveSync

## Installation

During the installation, you'll be asked:

```
Do you want to install a webmail client?

Choose a webmail client:
  1) SnappyMail (recommended - fast, modern, file-based)
  2) Roundcube (feature-rich, mature)
  3) SOGo (full groupware with calendar and contacts)
  4) No webmail client

Enter your choice (1-4): _
```

Simply select the option that best fits your needs.

## Comparison

### SnappyMail ⭐ (Option 1 - Recommended)

**Strengths:**
- 🚀 **Blazing fast** - Modern JavaScript, minimal overhead
- 📁 **No database required** - Uses file storage
- 🎨 **Clean, modern UI** - Responsive design
- 🔧 **Easy maintenance** - Simple setup and updates
- 💾 **Low resources** - Minimal server load

**Perfect for:**
- Personal mail servers
- Small teams (< 50 users)
- Performance-focused deployments
- Users who want simplicity

**Access:** `https://mail.yourdomain.com`

**Post-installation:**
1. Visit admin panel: `https://mail.yourdomain.com/?admin`
2. Default admin password: `12345` (**change immediately!**)
3. Configure domains and IMAP/SMTP settings
4. Users can then login with their email credentials

---

### Roundcube (Option 2 - Feature-Rich)

**Strengths:**
- 🎯 **Mature and stable** - Used by millions
- 🔌 **100+ plugins** - Highly extensible
- 📧 **Full-featured** - Advanced email management
- 🎨 **Modern "Elastic" skin** - Responsive interface
- 🗂️ **Managesieve support** - Server-side mail filters

**Perfect for:**
- Medium-sized organizations
- Power users who need plugins
- Users familiar with traditional webmail
- Feature-rich requirements

**Access:** `https://mail.yourdomain.com`

**Post-installation:**
- Users login directly with email credentials
- Admin can enable/disable plugins in config
- Supports custom themes and skins

**Key features:**
- HTML email composer
- Contact management
- Email archiving
- Advanced search
- Multiple identities
- Spell checking

---

### SOGo (Option 3 - Full Groupware)

**Strengths:**
- 📅 **Calendar (CalDAV)** - Full calendar integration
- 👥 **Contacts (CardDAV)** - Shared address books
- 📱 **ActiveSync** - Native iOS/Android sync
- 🏢 **Groupware features** - Team collaboration
- 🔗 **Outlook compatibility** - ConnectorSync plugin

**Perfect for:**
- Businesses and organizations
- Teams needing calendaring
- Mobile-first users (ActiveSync)
- Microsoft Outlook users
- Complete collaboration solution

**Access:** `https://mail.yourdomain.com/SOGo`

**Post-installation:**
- Users login with email credentials
- Calendar and contacts sync automatically
- Mobile devices can use ActiveSync (mail.yourdomain.com)

**Key features:**
- Integrated email, calendar, contacts
- Shared calendars
- Meeting invitations
- Resource booking
- Task management
- iOS/Android native sync
- Thunderbird/Outlook plugins

---

## Technical Details

### SnappyMail Installation

1. **Downloads latest release** from GitHub
2. **Extracts to** `/var/www/snappymail`
3. **Configures nginx** virtual host
4. **Sets permissions** for data directory
5. **No database setup** required

**Storage:** File-based (lightweight)

**Dependencies:**
- PHP 7.4+ with extensions: json, iconv, mbstring
- Nginx or Apache
- No database required

---

### Roundcube Installation

1. **Installs via package manager** (distro packages)
2. **Creates MySQL database** `roundcubemail`
3. **Imports schema** automatically
4. **Configures** `/etc/roundcube/config.inc.php`
5. **Sets up nginx** virtual host

**Storage:** MySQL database

**Dependencies:**
- PHP 7.4+ with extensions: mysql, imap, mbstring, json, xml
- MySQL/MariaDB database
- Nginx or Apache

**Database credentials:**
- Database: `roundcubemail`
- User: `roundcube`
- Password: Auto-generated (saved in installation summary)

---

### SOGo Installation

1. **Installs via package manager**
2. **Creates MySQL database** `sogo`
3. **Configures** `/etc/sogo/sogo.conf`
4. **Sets up ActiveSync**
5. **Integrates with Postfix/Dovecot**

**Storage:** MySQL database

**Dependencies:**
- MySQL/MariaDB database
- SOPE libraries
- GNUstep environment
- Nginx or Apache (reverse proxy)

**Database credentials:**
- Database: `sogo`
- User: `sogo`
- Password: Auto-generated (saved in installation summary)

**ActiveSync setup:**
- Server: `mail.yourdomain.com`
- Domain: Leave blank
- Username: Full email address
- SSL: Enabled

---

## Post-Installation

### SSL Certificates

All webmail installations use HTTPS via Let's Encrypt:

```bash
# The installer automatically configures nginx for SSL
# Certificates are obtained for: mail.yourdomain.com

# Manual renewal (if needed):
certbot renew
```

### Firewall Configuration

Don't forget to open ports:

```bash
# HTTPS for webmail
ufw allow 443/tcp

# HTTP for Let's Encrypt (redirects to HTTPS)
ufw allow 80/tcp
```

### Nginx Configuration

Webmail nginx configs are at:
- **SnappyMail:** `/etc/nginx/sites-available/snappymail`
- **Roundcube:** Configured via package
- **SOGo:** `/etc/nginx/sites-available/sogo`

Reload after changes:
```bash
nginx -t              # Test configuration
systemctl reload nginx
```

---

## Troubleshooting

### SnappyMail Issues

**Admin panel not loading:**
```bash
# Check permissions
chown -R www-data:www-data /var/www/snappymail
chmod 750 /var/www/snappymail/data

# Check nginx logs
tail -f /var/log/nginx/snappymail-error.log
```

**Can't login:**
1. Go to admin panel: `https://mail.yourdomain.com/?admin`
2. Check domains configuration
3. Test IMAP connection: `openssl s_client -connect localhost:993`

### Roundcube Issues

**Database connection error:**
```bash
# Check database
mysql -u roundcube -p roundcubemail

# Verify password in config
grep db_dsnw /etc/roundcube/config.inc.php
```

**Plugin issues:**
```bash
# Check enabled plugins
grep plugins /etc/roundcube/config.inc.php

# Plugin directory
ls -la /usr/share/roundcube/plugins/
```

### SOGo Issues

**Service not starting:**
```bash
# Check SOGo status
systemctl status sogo

# View logs
journalctl -u sogo -f
```

**ActiveSync not working:**
1. Verify `SOGoEnableEAS = YES` in `/etc/sogo/sogo.conf`
2. Check mobile device uses: `mail.yourdomain.com` (no /SOGo)
3. SSL must be enabled

**Database issues:**
```bash
# Check SOGo database
mysql -u sogo -p sogo

# Verify connection string in config
grep SOGoProfileURL /etc/sogo/sogo.conf
```

---

## Choosing the Right Option

### Decision Tree

**Do you need calendar/contacts?**
- ✅ Yes → Choose **SOGo** (#3)
- ❌ No → Continue...

**Do you need lots of plugins and customization?**
- ✅ Yes → Choose **Roundcube** (#2)
- ❌ No → Continue...

**Do you want the fastest, simplest option?**
- ✅ Yes → Choose **SnappyMail** (#1) ⭐

**Don't need webmail at all?**
- Choose **No webmail** (#4)
- Users can still use desktop clients (Thunderbird, Outlook, etc.)

---

## Comparison Table

| Feature | SnappyMail | Roundcube | SOGo |
|---------|------------|-----------|------|
| **Performance** | ⚡⚡⚡ Excellent | ⚡⚡ Good | ⚡ Moderate |
| **Memory Usage** | ~50MB | ~100MB | ~200MB+ |
| **Disk Space** | ~10MB | ~50MB | ~100MB+ |
| **Database** | None | MySQL | MySQL |
| **Setup Time** | 2 minutes | 5 minutes | 10 minutes |
| **Maintenance** | Very Low | Low | Medium |
| **Learning Curve** | Easy | Easy | Moderate |
| **Email** | ✅ Full | ✅ Full | ✅ Full |
| **Calendar** | ❌ | ❌ | ✅ CalDAV |
| **Contacts** | ✅ Basic | ✅ Good | ✅ CardDAV |
| **Mobile Sync** | ❌ | ❌ | ✅ ActiveSync |
| **Filters** | ✅ Basic | ✅ Sieve | ✅ Sieve |
| **Plugins** | 🟡 Some | ✅ 100+ | 🟢 Built-in |
| **Themes** | 🟡 Few | ✅ Many | 🟢 Built-in |
| **Multi-language** | ✅ | ✅ | ✅ |
| **2FA Support** | ✅ | 🟡 Plugin | ✅ |

---

## Recommendations by Use Case

### Home User / Personal Server
**Choose: SnappyMail** (#1)
- Lightweight and fast
- No database overhead
- Easy to maintain

### Small Business (< 20 users)
**Choose: SnappyMail or Roundcube**
- SnappyMail: If speed matters
- Roundcube: If you need plugins

### Medium Business (20-100 users)
**Choose: Roundcube or SOGo**
- Roundcube: Email-focused
- SOGo: Need calendar/contacts

### Large Organization (100+ users)
**Choose: SOGo**
- Full groupware suite
- ActiveSync for mobile
- Shared calendars and resources

### Developer / Tech-Savvy
**Choose: SnappyMail or Roundcube**
- SnappyMail: Minimalist, fast
- Roundcube: Extensible, customizable

---

## Resources

### SnappyMail
- Website: https://snappymail.eu/
- GitHub: https://github.com/the-djmaze/snappymail
- Documentation: https://snappymail.eu/docs/

### Roundcube
- Website: https://roundcube.net/
- GitHub: https://github.com/roundcube/roundcubemail
- Documentation: https://github.com/roundcube/roundcubemail/wiki
- Plugins: https://plugins.roundcube.net/

### SOGo
- Website: https://sogo.nu/
- Documentation: https://sogo.nu/support.html
- Mobile Setup: https://sogo.nu/support/faq/how-to-configure-ios.html

---

## Summary

All three webmail clients are:
- ✅ **Fully integrated** with your mail server
- ✅ **Automatically configured** by the installer
- ✅ **HTTPS-enabled** via Let's Encrypt
- ✅ **Production-ready** out of the box

Choose based on your needs:
- **Speed & Simplicity** → SnappyMail ⭐
- **Features & Plugins** → Roundcube
- **Calendar & Mobile** → SOGo

Or skip webmail entirely and use desktop clients!
