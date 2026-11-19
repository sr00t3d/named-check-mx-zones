# Check MX Zones in NAMED

Readme: [BR](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="named-check-mx-zones-cover.webp" />

A high-performance Bash script designed for DevOps teams and system administrators to validate local BIND/Named DNS zone files (in cPanel, DirectAdmin, or standalone servers) against live DNS queries on authoritative or public recursive nameservers.

The script scans zone files (`.db`), queries the configured nameservers, cross-validates records to spot propagation discrepancies or desync, optionally validates domain registration via WHOIS, and outputs structured reports (Table, JSON, CSV).

## 🚀 Features (v1.2.0)

* **Concurrent Multi-Threaded Scanning (`-j, --jobs`):** Drastically accelerates execution across hundreds or thousands of domains using concurrent background worker jobs.
* **Structured Output Formats (`-o table|json|csv`):** Native export to JSON or CSV for seamless integration with CI/CD pipelines, Zabbix, Prometheus, SIEM, or monitoring dashboards.
* **Single-Domain Mode (`-D, --domain`):** Instant diagnosis for a single domain or specific zone file without scanning the entire `/var/named` directory.
* **Issues-Only Filter (`-e, --only-issues`):** Highlights only discrepancies (`DESYNC`, `NO_MX`, `EXTERNAL_MX`, `NOT_REGISTERED`), filtering out clean records.
* **Authoritative Discovery Mode (`--auth`):** Queries each domain's authoritative delegated nameservers in real-time instead of static public resolvers.
* **Automatic Nameserver Detection:** Auto-detects nameservers from `/etc/nameserverips` (cPanel) or `/etc/resolv.conf`, with fallback to `1.1.1.1` and `8.8.8.8`.
* **Granular MX Status:**
  * `OK`: MX record synchronized across nameservers and matches configuration.
  * `EXTERNAL_MX`: Valid and synchronized, but pointing to an external provider (Google Workspace, Microsoft 365, Zoho, etc.).
  * `DESYNC`: Discrepancy between `NS1` and `NS2` responses (propagation lag or DNS cluster replication issue).
  * `NO_MX`: No MX records returned by nameservers.
  * `NOT_REGISTERED`: Domain is expired or available for registration according to WHOIS.
* **Robust BIND Parser:** Supports `@` origin notation, TTL directives, inline comments (`;`), and varied MX record priorities.
* **Safe WHOIS Verification:** Multi-TLD support (`.br`, `.com`, `.net`, `.io`, etc.) with built-in query timeouts to prevent hangs.
* **Table Formatting with Color:** Colored terminal output with automated fallback for environments lacking the `column` binary.

## 📋 Prerequisites

The script requires the following utilities:

* `bash` (4.0+)
* `dig` (`bind-utils` package on RHEL/CentOS/AlmaLinux or `dnsutils` on Debian/Ubuntu)
* `whois` (optional; automatically skipped if not installed)
* `python3` (optional; only needed when exporting with `-o json`)
* `column` (optional; native formatted `printf` fallback included)

## 🔧 Usage & Options

```text
Named Check MX Zones v1.2.0

Usage: check-mx-zones.sh [OPTIONS]

Scope & Directory Options:
  -d, --dir DIR          Directory containing BIND/Named .db zone files (default: /var/named)
  -D, --domain DOMAIN    Check a single domain or specific zone file directly
  -a, --all              Check all MX records, not only local mail.<domain>

DNS & Network Options:
  -1, --ns1 SERVER       Primary nameserver IP/host to query (default: auto-detected or 1.1.1.1)
  -2, --ns2 SERVER       Secondary nameserver IP/host to query (default: auto-detected or 8.8.8.8)
  --auth, --authoritative Query each domain's delegated authoritative nameservers
  -t, --timeout SEC      DNS query timeout per nameserver in seconds (default: 2)
  -j, --jobs NUM         Number of parallel jobs for concurrent checking (default: 5, 1=sequential)
  -w, --skip-whois       Skip WHOIS domain registration lookups for ultra-fast scans

Output & Reporting Options:
  -o, --output FORMAT    Output format: table (default), json, csv
  -e, --only-issues      Only report domains with discrepancies
  -v, --verbose          Print per-domain check details to stderr
  --no-color             Disable colored terminal output
  -h, --help             Show this help message and exit
```

## 💡 Practical Examples

* **Standard scan with auto-detected nameservers:**
  ```bash
  ./check-mx-zones.sh
  ```

* **Fast multi-threaded scan (10 threads) exporting to JSON:**
  ```bash
  ./check-mx-zones.sh -j 10 --skip-whois -o json > audit.json
  ```

* **Single-domain check against authoritative nameservers:**
  ```bash
  ./check-mx-zones.sh -D example.com --auth -a
  ```

* **Audit discrepancies only and export to CSV:**
  ```bash
  ./check-mx-zones.sh -e -o csv > issues.csv
  ```

* **Custom directory with custom nameservers:**
  ```bash
  ./check-mx-zones.sh -d /var/named -1 ns1.example.com -2 ns2.example.com
  ```

## 📝 Example Output

### Table Format:
```text
Starting Named Check MX Zones (v1.2.0)...
Diretório de Zonas: /var/named
Nameserver 1:       1.1.1.1
Nameserver 2:       8.8.8.8
DNS Timeout:        2s
Concorrência:       5 threads simultâneas
Filtro WHOIS:       Ativado
Filtro de Escopo:   Todos os MX

================================================================================
DOMAIN                REGISTERED  MX RECORD             STATUS
--------------------------------------------------------------------------------
example.com           YES         0 mail.example.com.   OK
client-corp.com       YES         10 aspmx.l.google.com. EXTERNAL_MX
desync-domain.org     YES         10 mail.desync.org.   DESYNC
abandoned-zone.net    NO          (none)                NOT_REGISTERED
================================================================================
Total de zonas auditadas: 4
Resumo: Encontradas 3 divergência(s) (verifique STATUS acima).
Tempo total de execução: 1s
```

### JSON Format (`-o json`):
```json
{
  "version": "1.2.0",
  "total_checked": 2,
  "issues_found": 1,
  "execution_time_seconds": 0.45,
  "results": [
    {
      "domain": "example.com",
      "registered": "YES",
      "mx_records": ["0 mail.example.com."],
      "status": "OK",
      "has_issue": false
    },
    {
      "domain": "abandoned-zone.net",
      "registered": "NO",
      "mx_records": [],
      "status": "NOT_REGISTERED",
      "has_issue": true
    }
  ]
}
```

## 📄 License

This project is licensed under the [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
