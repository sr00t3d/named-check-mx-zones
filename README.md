# Check MX Zones in NAMED

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="named-check-mx-zones-cover.webp" />

A modern Bash script designed for system administrators and DevOps teams to validate local BIND/Named DNS zone files (in cPanel, DirectAdmin, or standalone servers) against live DNS queries on authoritative or public recursive nameservers.

The script scans zone files (`.db`), queries the configured nameservers, cross-validates records to spot propagation discrepancies or desync, optionally validates domain registration via WHOIS, and provides granular status reporting.

## 🚀 Features (v1.1.0)

* **Automatic Nameserver Detection:** Auto-detects nameservers from `/etc/nameserverips` (cPanel) or `/etc/resolv.conf`, with intelligent fallback to `1.1.1.1` and `8.8.8.8`.
* **Command-Line Arguments:** Configure zone directory, nameservers, query timeout, and filters directly via CLI flags without modifying code.
* **MX Consistency & Granular Status:**
  * `OK`: MX record synchronized across nameservers and matches configuration.
  * `EXTERNAL_MX`: Valid and synchronized, but pointing to an external provider (Google Workspace, Microsoft 365, Zoho, etc.).
  * `DESYNC`: Discrepancy between `NS1` and `NS2` responses (propagation lag or DNS cluster replication issue).
  * `NO_MX`: No MX records returned by nameservers.
* **Robust BIND Parser:** Supports `@` origin notation, TTL directives, and various MX record priorities.
* **Safe WHOIS Verification:** Multi-TLD support (`.br`, `.com`, `.net`, `.io`, etc.) with built-in query timeouts to prevent hangs on sluggish servers, plus `--skip-whois` for fast batch audits.
* **Clean Table Output & Colors:** Aligned, colored terminal output with automated fallback for environments lacking the `column` binary.

## 📋 Prerequisites

The script requires the following utilities:

* `bash` (4.0+)
* `dig` (`bind-utils` package on RHEL/CentOS/AlmaLinux or `dnsutils` on Debian/Ubuntu)
* `whois` (optional; automatically skipped if not installed)
* `column` (optional; native formatted `printf` fallback included)

## 🔧 Usage & Examples

**1. Download the script:**

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/named-check-mx-zones/refs/heads/main/check-mx-zones.sh
chmod +x check-mx-zones.sh
```

**2. Available Options:**

```text
Usage: check-mx-zones.sh [OPTIONS]

Options:
  -d, --dir DIR          Directory containing BIND/Named .db zone files (default: /var/named)
  -1, --ns1 SERVER       Primary nameserver IP/host to query (default: auto-detected or 1.1.1.1)
  -2, --ns2 SERVER       Secondary nameserver IP/host to query (default: auto-detected or 8.8.8.8)
  -t, --timeout SEC      DNS query timeout in seconds (default: 2)
  -w, --skip-whois       Skip WHOIS lookups for faster execution
  -a, --all              Check all MX records, not only local mail.<domain>
  -v, --verbose          Print per-domain progress during execution
  --no-color             Disable colored output
  -h, --help             Show this help message and exit
```

**3. Practical Examples:**

* **Standard execution (auto-detects nameservers and scans `/var/named`):**
  ```bash
  ./check-mx-zones.sh
  ```

* **Targeting specific authoritative nameservers:**
  ```bash
  ./check-mx-zones.sh -1 ns1.yourdomain.com -2 ns2.yourdomain.com
  ```

* **Fast scan skipping WHOIS queries:**
  ```bash
  ./check-mx-zones.sh --skip-whois -a
  ```

* **Custom directory with reduced timeout:**
  ```bash
  ./check-mx-zones.sh -d /etc/bind/zones -t 1 --skip-whois
  ```

## 📝 Example Output

```text
Starting DNS Zone check (v1.1.0)...
Scanning directory: /var/named
Nameserver 1 (NS1): 1.1.1.1
Nameserver 2 (NS2): 8.8.8.8
DNS Query Timeout:  2s
WHOIS Lookups:      Enabled
Filter:             All MX zones

================================================================================
DOMAIN                REGISTERED  MX RECORD             STATUS
--------------------------------------------------------------------------------
example.com           YES         0 mail.example.com.   OK
external-client.com   YES         10 aspmx.l.google.com. EXTERNAL_MX
desync-domain.org     YES         10 mail.desync.org.   DESYNC
stale-zone.net        NO          (none)                NO_MX
================================================================================
Total zones checked: 4
Summary: Discrepancies found (Check ERROR/DESYNC/EXTERNAL_MX/NO_MX status).
Total execution time: 2s
```

## ⚠️ Disclaimer

> [!WARNING]
> This software is provided "as is". Always ensure you test in a development environment first. The author is not responsible for any misuse, legal consequences, or data impact caused by this tool.

---

## 📚 Detailed Tutorial

For a complete step-by-step tutorial, check the blog article:

👉 [**Check MX Zones in NAMED**](https://perciocastelo.com.br/blog/check-domains-zone-mx-in-named.html)

## License 📄

This project is licensed under the **Apache License 2.0**. See the [LICENSE](LICENSE) file for details.
