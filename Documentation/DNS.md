# DNS Configuration Guide

Complete guide to setting up DNS records for your mail server.

## Why DNS Matters

DNS (Domain Name System) tells the internet:
- Where to send emails for your domain (MX record)
- Where your mail server is located (A record)
- That your server is authorized to send email (SPF, DKIM, DMARC)
- How to verify your server's identity (Reverse DNS)

**Don't worry!** We provide step-by-step instructions for popular providers.

## Required DNS Records

### 1. A Record (Required)

**Points your mail hostname to your server's IP address.**

```
Type:  A
Name:  mail  (or your chosen hostname)
Value: YOUR_SERVER_IP
TTL:   3600 (or automatic)
```

Example: `mail.example.com` → `203.0.113.10`

### 2. MX Record (Required)

**Tells other servers where to deliver email for your domain.**

```
Type:     MX
Name:     @  (root domain)
Value:    mail.example.com  (your hostname)
Priority: 10
TTL:      3600
```

### 3. SPF Record (Strongly Recommended)

**Prevents email spoofing and improves deliverability.**

```
Type:  TXT
Name:  @  (root domain)
Value: "v=spf1 mx a ~all"
```

**What this means:**
- `v=spf1` - SPF version 1
- `mx` - Allow servers in MX records
- `a` - Allow server from A record
- `~all` - Soft fail for others (recommended)

### 4. DMARC Record (Recommended)

**Email authentication policy and reporting.**

```
Type:  TXT
Name:  _dmarc
Value: "v=DMARC1; p=none; rua=mailto:admin@example.com"
```

**What this means:**
- `v=DMARC1` - DMARC version 1
- `p=none` - Monitor only (no enforcement yet)
- `rua=mailto:...` - Where to send reports

After a few weeks, you can change `p=none` to `p=quarantine` or `p=reject`.

### 5. Autoconfig Records (Optional but Recommended)

**Enables automatic email client configuration.**

```
Type:  A
Name:  autoconfig
Value: YOUR_SERVER_IP

Type:  A
Name:  autodiscover  
Value: YOUR_SERVER_IP
```

### 6. Reverse DNS / PTR Record (Critical)

**Proves your server owns the IP address.**

⚠️ **You cannot set this yourself!** Contact your hosting provider.

**What to request:**
"Please set the PTR record for [YOUR_SERVER_IP] to point to [mail.example.com]"

## Provider-Specific Guides

### Cloudflare

1. Log in: https://dash.cloudflare.com/
2. Select your domain
3. Click "DNS" in top menu
4. Click "Add record" for each entry

**Important:** Turn OFF the orange cloud (proxy) for mail records!

#### A Records
```
Type: A | Name: mail         | IPv4: YOUR_IP | Proxy: OFF 🔴
Type: A | Name: autoconfig   | IPv4: YOUR_IP | Proxy: OFF 🔴
Type: A | Name: autodiscover | IPv4: YOUR_IP | Proxy: OFF 🔴
```

#### MX Record
```
Type: MX | Name: @ | Server: mail.example.com | Priority: 10
```

#### TXT Records
```
Type: TXT | Name: @      | Content: v=spf1 mx a ~all
Type: TXT | Name: _dmarc | Content: v=DMARC1; p=none; rua=mailto:admin@example.com
```

### GoDaddy

1. Log in: https://dcc.godaddy.com/manage/dns
2. Find your domain and click "DNS"
3. Scroll to "Records" section
4. Click "Add" for each record

```
A Record:
Type: A | Name: mail         | Value: YOUR_IP | TTL: 1 Hour

MX Record:
Type: MX | Name: @ | Value: mail.example.com | Priority: 10 | TTL: 1 Hour

TXT Records:
Type: TXT | Name: @      | Value: v=spf1 mx a ~all
Type: TXT | Name: _dmarc | Value: v=DMARC1; p=none; rua=mailto:admin@example.com
```

### Namecheap

1. Log in: https://ap.www.namecheap.com/domains/list/
2. Click "Manage" next to your domain
3. Click "Advanced DNS" tab
4. Click "Add New Record"

```
A Records:
Type: A Record | Host: mail         | Value: YOUR_IP | TTL: Automatic

MX Record:
Type: MX Record | Host: @ | Value: mail.example.com | Priority: 10

TXT Records:
Type: TXT Record | Host: @      | Value: v=spf1 mx a ~all
Type: TXT Record | Host: _dmarc | Value: v=DMARC1; p=none; rua=mailto:admin@example.com
```

### Google Domains / Cloud DNS

1. Log in: https://domains.google.com/
2. Click your domain
3. Click "DNS" in left menu
4. Click "Manage custom records"

```
Host name    | Type | TTL  | Data
mail         | A    | 3600 | YOUR_IP
autoconfig   | A    | 3600 | YOUR_IP
autodiscover | A    | 3600 | YOUR_IP
@            | MX   | 3600 | 10 mail.example.com
@            | TXT  | 3600 | v=spf1 mx a ~all
_dmarc       | TXT  | 3600 | v=DMARC1; p=none; rua=mailto:admin@example.com
```

### Amazon Route 53

1. Log in: https://console.aws.amazon.com/route53/
2. Click "Hosted zones"
3. Select your domain
4. Click "Create record"

```
Record name: mail
Record type: A
Value: YOUR_IP
TTL: 300
Routing policy: Simple

Record name: @ (leave blank)
Record type: MX
Value: 10 mail.example.com
TTL: 300

Record name: @ (leave blank)
Record type: TXT
Value: "v=spf1 mx a ~all"
TTL: 300

Record name: _dmarc
Record type: TXT
Value: "v=DMARC1; p=none; rua=mailto:admin@example.com"
TTL: 300
```

### Other Providers

Look for these sections in your DNS control panel:
- "DNS Management"
- "DNS Settings"
- "Zone File Editor"
- "Manage DNS Records"

Add the records as shown in the [Required DNS Records](#required-dns-records) section.

## Testing DNS Records

### Check A Record
```bash
dig mail.example.com A
# or
nslookup mail.example.com
```

Expected: Your server's IP address

### Check MX Record
```bash
dig example.com MX
# or
nslookup -type=MX example.com
```

Expected: Priority 10, pointing to your mail hostname

### Check SPF Record
```bash
dig example.com TXT | grep spf
```

Expected: `v=spf1 mx a ~all`

### Check DMARC Record
```bash
dig _dmarc.example.com TXT
```

Expected: `v=DMARC1; p=none; ...`

### Check Reverse DNS
```bash
dig -x YOUR_SERVER_IP
# or
nslookup YOUR_SERVER_IP
```

Expected: Your mail hostname (mail.example.com)

### Online Testing Tools

- **MX Toolbox**: https://mxtoolbox.com/
  - Comprehensive DNS and mail server testing
  - Check blacklists
  - Test SPF/DMARC/DKIM

- **What's My DNS**: https://www.whatsmydns.net/
  - Check DNS propagation worldwide
  - See how different regions resolve your domain

- **DNS Checker**: https://dnschecker.org/
  - Test DNS propagation
  - Check all record types

- **IntoDNS**: https://intodns.com/
  - Comprehensive DNS health check
  - Identifies configuration problems

## DNS Propagation Time

After adding/changing DNS records:
- **Minimum**: 15-30 minutes
- **Typical**: 2-4 hours
- **Maximum**: 24-48 hours

The TTL (Time To Live) value controls caching:
- Lower TTL = Faster updates but more DNS queries
- Higher TTL = Slower updates but better performance

**Recommendation**: Use TTL 3600 (1 hour) for stability.

## Common DNS Issues

### Issue: Records Not Resolving

**Causes:**
- DNS not yet propagated
- Typo in record name/value
- Wrong DNS zone

**Solutions:**
1. Wait for propagation (up to 48 hours)
2. Verify records at DNS provider
3. Clear local DNS cache: `sudo systemd-resolve --flush-caches`
4. Use different DNS server for testing: `dig @8.8.8.8 yourdomain.com`

### Issue: MX Record Not Working

**Causes:**
- Missing dot at end of hostname
- Wrong priority
- A record for mail hostname missing

**Solutions:**
1. Ensure format: `10 mail.example.com.` (note the trailing dot)
2. Verify A record exists for mail hostname
3. Test: `dig example.com MX`

### Issue: Emails Going to Spam

**Causes:**
- Missing SPF record
- Missing reverse DNS
- DKIM not configured
- No DMARC policy

**Solutions:**
1. Verify all DNS records are correct
2. Contact hosting provider for reverse DNS
3. Wait for DNS propagation
4. Test at: https://www.mail-tester.com/

### Issue: Reverse DNS Not Set

**Causes:**
- Only hosting provider can set PTR records
- Request not yet processed

**Solutions:**
1. Open support ticket with hosting provider
2. Provide: IP address and desired hostname
3. Wait for confirmation (usually < 24 hours)
4. Verify: `dig -x YOUR_IP`

## Advanced Configuration

### Multiple Domains

For additional domains, repeat these records:
```
Additional MX record:
Type: MX | Name: @  (for each domain) | Value: mail.example.com

Additional SPF/DMARC for each domain:
Type: TXT | Name: @      | Value: v=spf1 mx a ~all
Type: TXT | Name: _dmarc | Value: v=DMARC1; p=none; ...
```

### DKIM Record

After OpenDKIM is configured, add:
```
Type: TXT
Name: default._domainkey
Value: (long public key from /etc/opendkim/keys/yourdomain/default.txt)
```

See [Security Guide](SECURITY.md) for DKIM setup.

### IPv6 Support

If your server has IPv6:
```
Type: AAAA
Name: mail
Value: YOUR_IPV6_ADDRESS
```

Also update SPF record:
```
v=spf1 mx a ip6:YOUR_IPV6/64 ~all
```

## DNS Security

### DNSSEC

Some providers support DNSSEC (DNS Security Extensions):
- Cryptographically signs DNS records
- Prevents DNS spoofing
- Optional but recommended

Check if your provider supports it and follow their guide.

### CAA Records (Optional)

Restrict which certificate authorities can issue SSL certificates:
```
Type: CAA
Name: @
Value: 0 issue "letsencrypt.org"
```

## Quick Reference

### Minimal Setup (Required)
```
mail.example.com.     IN  A    YOUR_SERVER_IP
example.com.          IN  MX   10 mail.example.com.
```

### Recommended Setup
```
mail.example.com.     IN  A    YOUR_SERVER_IP
autoconfig.example.com. IN A   YOUR_SERVER_IP
autodiscover.example.com. IN A YOUR_SERVER_IP
example.com.          IN  MX   10 mail.example.com.
example.com.          IN  TXT  "v=spf1 mx a ~all"
_dmarc.example.com.   IN  TXT  "v=DMARC1; p=none; rua=mailto:admin@example.com"
```

### Plus Reverse DNS (from hosting provider)
```
YOUR_SERVER_IP  PTR  mail.example.com.
```

## Next Steps

After DNS is configured:
1. Wait for propagation (2-4 hours typically)
2. Test DNS records (see [Testing](#testing-dns-records) above)
3. Continue with installation
4. Test mail server: `./test-server.sh`
