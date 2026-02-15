# Check MX Zones in NAMED

Readme: [Português](README-ptbr.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones)
![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

A Bash script designed for system administrators to validate local DNS zone files against live nameserver queries. It specifically targets domains configured with a local MX record pointing to `mail.domain.tld`.

The script iterates through zone files (usually BIND/Named), queries two defined nameservers, cross-references the results, and checks the domain's registration status via WHOIS.

## 🚀 Features

* **MX Consistency:** Compares MX records returned by `NS1` and `NS2` to ensure synchronization.
* **Configuration Validation:** Specifically verifies that the live MX record matches the local configuration (targeting `mail.domain` with priority `0`).
* **Registration Check:** Performs a `whois` lookup to verify if the domain is currently registered or available (useful for cleaning up old zones).
* **Formatted Output:** Generates an aligned table for easy reading.

## 📋 Prerequisites

The script requires the following utilities installed on the host system:

* `bash` (4.0+)
* `dig` (usually part of `bind-utils` or `dnsutils`)
* `whois`
* `column` (part of `util-linux` or `bsdmainutils`)

## ⚙️ Configuration

Open the script and modify the variables at the top of the file to match your environment:

```bash
NS1="ns1.yourserver.com"   # Primary Nameserver to query
NS2="ns2.yourserver.com"   # Secondary Nameserver to query
ZONEDIR="/var/named"       # Directory containing .db zone files
```

## 🔧 Usage

**1. Download the script (e.g., check-mx-zones):**

```bash
wget https://raw.githubusercontent.com/sr00t3d/named-check-mx-zones/refs/heads/main/check-mx-zones.sh
```

**2. Make it executable:**

```bash
chmod +x check-mx-zones.sh
```

**Run the script (may require `sudo` depending on read permissions of your `$ZONEDIR`):**

```bash
sudo ./check-mx-zones.sh
```

## ⚠️ Important Notes

> Whois Rate Limiting: The script performs a whois lookup for every matching domain. If you have hundreds of domains, this may trigger rate limiting from WHOIS providers or slow down execution significantly.

> Target Logic: The script currently filters for local zone files containing IN MX [priority] mail.domain.. If your zone files use a different format (e.g., pointing to Google Workspace or Office 365 directly), they will be skipped unless you modify the grep regex logic inside the loop.

📝 Output Example

```bash
DOMAIN          REGISTERED  MX RECORD             STATUS
example.com     YES         0 mail.example.com.   OK
test-site.net   NO          0 mail.test-site.net. ERROR
```

## ⚠️ Disclaimer

> [!WARNING]
> This software is provided "as-is". While extensively tested in named environments. The author is not responsible for any data loss.

---

## 📚 Detailed Tutorial

For a complete step-by-step guide, check out my full article:

👉 [**Check Domain Zones MX in NAMED**](https://perciocastelo.com.br/blog/check-domains-zone-mx-in-named.html)

## License 📄

This project is licensed under the **GNU General Public License v3.0**. See the [LICENSE](LICENSE) file for details.
