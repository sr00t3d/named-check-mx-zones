#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Named Check MX Zones v1.1.0                                             ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: contato@perciocastelo.com.br                                   ║
# ║   Website: https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Check MX zones from .db domain                                 ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -o pipefail

# ==============================================================================
# CONFIGURATION & DEFAULTS
# ==============================================================================
ZONEDIR="/var/named"
NS1=""
NS2=""
TIMEOUT=2
TRIES=1
SKIP_WHOIS=false
CHECK_ONLY_LOCAL=true
VERBOSE=false
USE_COLOR=true

# Disable colors if stdout is not a terminal
if [[ ! -t 1 ]]; then
    USE_COLOR=false
fi

# Colors
if [[ "$USE_COLOR" = true ]]; then
    C_RESET='\033[0m'
    C_GREEN='\033[0;32m'
    C_RED='\033[0;31m'
    C_YELLOW='\033[0;33m'
    C_BLUE='\033[0;34m'
    C_BOLD='\033[1m'
else
    C_RESET=''
    C_GREEN=''
    C_RED=''
    C_YELLOW=''
    C_BLUE=''
    C_BOLD=''
fi

# ==============================================================================
# USAGE
# ==============================================================================
usage() {
    cat << EOF
Named Check MX Zones v1.1.0

Usage: $(basename "$0") [OPTIONS]

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

Examples:
  $(basename "$0")
  $(basename "$0") -d /var/named -1 ns1.example.com -2 ns2.example.com
  $(basename "$0") --skip-whois --all
EOF
    exit 0
}

# ==============================================================================
# PARSE ARGUMENTS
# ==============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dir)
            ZONEDIR="$2"; shift 2 ;;
        -1|--ns1)
            NS1="$2"; shift 2 ;;
        -2|--ns2)
            NS2="$2"; shift 2 ;;
        -t|--timeout)
            TIMEOUT="$2"; shift 2 ;;
        -w|--skip-whois)
            SKIP_WHOIS=true; shift ;;
        -a|--all)
            CHECK_ONLY_LOCAL=false; shift ;;
        -v|--verbose)
            VERBOSE=true; shift ;;
        --no-color)
            USE_COLOR=false
            C_RESET='' C_GREEN='' C_RED='' C_YELLOW='' C_BLUE='' C_BOLD=''
            shift ;;
        -h|--help)
            usage ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage ;;
    esac
done

# ==============================================================================
# AUTO-DETECT NAMESERVERS
# ==============================================================================
if [[ -z "$NS1" || -z "$NS2" ]]; then
    # Try cPanel /etc/nameserverips
    if [[ -f /etc/nameserverips ]]; then
        mapfile -t detected_ns < <(awk '{print $1}' /etc/nameserverips 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        [[ -z "$NS1" && -n "${detected_ns[0]:-}" ]] && NS1="${detected_ns[0]}"
        [[ -z "$NS2" && -n "${detected_ns[1]:-}" ]] && NS2="${detected_ns[1]}"
    fi

    # Try /etc/resolv.conf
    if [[ -z "$NS1" || -z "$NS2" ]] && [[ -f /etc/resolv.conf ]]; then
        mapfile -t resolv_ns < <(awk '/^nameserver/ {print $2}' /etc/resolv.conf 2>/dev/null | grep -vE '^(127\.|::1)')
        [[ -z "$NS1" && -n "${resolv_ns[0]:-}" ]] && NS1="${resolv_ns[0]}"
        [[ -z "$NS2" && -n "${resolv_ns[1]:-}" ]] && NS2="${resolv_ns[1]}"
    fi

    # Fallback to public resolvers
    [[ -z "$NS1" ]] && NS1="1.1.1.1"
    [[ -z "$NS2" ]] && NS2="8.8.8.8"
fi

# ==============================================================================
# DEPENDENCIES
# ==============================================================================
if ! command -v dig &> /dev/null; then
    echo "Error: 'dig' is required. Please install bind-utils (RHEL/Alma) or dnsutils (Debian/Ubuntu)." >&2
    exit 1
fi

if [[ "$SKIP_WHOIS" = false ]] && ! command -v whois &> /dev/null; then
    echo "Warning: 'whois' command not found. Disabling WHOIS domain registration lookups." >&2
    SKIP_WHOIS=true
fi

# ==============================================================================
# SCAN ZONES
# ==============================================================================
if [[ ! -d "$ZONEDIR" ]]; then
    echo "Error: Zone directory '$ZONEDIR' does not exist." >&2
    exit 1
fi

diff_found=0
total_checked=0
output_buffer=""
SECONDS=0

echo -e "${C_BOLD}Starting DNS Zone check (v1.1.0)...${C_RESET}"
echo "Scanning directory: $ZONEDIR"
echo "Nameserver 1 (NS1): $NS1"
echo "Nameserver 2 (NS2): $NS2"
echo "DNS Query Timeout:  ${TIMEOUT}s"
echo "WHOIS Lookups:      $([[ "$SKIP_WHOIS" = true ]] && echo "Disabled" || echo "Enabled")"
echo "Filter:             $([[ "$CHECK_ONLY_LOCAL" = true ]] && echo "Only local mail.<domain>" || echo "All MX zones")"
echo

while IFS= read -r -d '' f; do
    domain="${f##*/}"
    domain="${domain%.db}"

    # Skip system default/reverse zone files
    case "$domain" in
        named.ca|named.empty|named.localhost|named.loopback|named.broadcast|named.local|named.ip6.local|named.zero|localdomain|localhost)
            continue
            ;;
    esac

    # Regex check against local zone file
    escaped_domain="$(printf '%s\n' "$domain" | sed 's/[^^]/[&]/g; s/\^/\\^/g')"
    should_check=false

    if [[ "$CHECK_ONLY_LOCAL" = true ]]; then
        if grep -E -q "^[[:space:]]*(@|[[:alnum:]_.-]+)?[[:space:]]+([0-9]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+[0-9]+[[:space:]]+(mail\.${escaped_domain}\.?|mail[[:space:]]*$)" "$f"; then
            should_check=true
        fi
    else
        if grep -E -q "^[[:space:]]*(@|[[:alnum:]_.-]+)?[[:space:]]+([0-9]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+" "$f"; then
            should_check=true
        fi
    fi

    if [[ "$should_check" = true ]]; then
        total_checked=$((total_checked + 1))
        [[ "$VERBOSE" = true ]] && echo "Checking: $domain"

        # Query both nameservers
        ns1_result="$(dig +time="$TIMEOUT" +tries="$TRIES" +short @"$NS1" "$domain" MX 2>/dev/null | sort)"
        ns2_result="$(dig +time="$TIMEOUT" +tries="$TRIES" +short @"$NS2" "$domain" MX 2>/dev/null | sort)"

        # Evaluate MX Status
        if [[ -z "$ns1_result" && -z "$ns2_result" ]]; then
            status="NO_MX"
            diff_found=1
        elif [[ "$ns1_result" != "$ns2_result" ]]; then
            status="DESYNC"
            diff_found=1
        elif echo "$ns1_result" | grep -E -qi "[0-9]+[[:space:]]+mail\.${escaped_domain}\.?"; then
            status="OK"
        else
            if [[ "$CHECK_ONLY_LOCAL" = true ]]; then
                status="EXTERNAL_MX"
                diff_found=1
            else
                status="OK"
            fi
        fi

        # WHOIS domain registration check
        if [[ "$SKIP_WHOIS" = true ]]; then
            registered="SKIP"
        else
            whois_out="$(timeout 5 whois "$domain" 2>/dev/null || true)"
            if [[ -z "$whois_out" ]]; then
                registered="TIMEOUT"
            elif echo "$whois_out" | grep -E -iq '(no match|not found|no data found|status:\s*free|domain not found|is free|available for registration)'; then
                registered="NO"
                diff_found=1
            else
                registered="YES"
            fi
        fi

        # Colored status formatting for table
        display_status="$status"
        if [[ "$USE_COLOR" = true ]]; then
            case "$status" in
                OK)          display_status="${C_GREEN}OK${C_RESET}" ;;
                EXTERNAL_MX) display_status="${C_YELLOW}EXTERNAL_MX${C_RESET}" ;;
                DESYNC)      display_status="${C_RED}DESYNC${C_RESET}" ;;
                NO_MX)       display_status="${C_RED}NO_MX${C_RESET}" ;;
                *)           display_status="${C_RED}${status}${C_RESET}" ;;
            esac
        fi

        # Buffer output lines
        first_line=1
        effective_result="${ns1_result:-$ns2_result}"
        if [[ -z "$effective_result" ]]; then
            output_buffer+="$domain\t$registered\t(none)\t$display_status\n"
        else
            while IFS= read -r mx_record; do
                if [[ -n "$mx_record" ]]; then
                    if [[ $first_line -eq 1 ]]; then
                        output_buffer+="$domain\t$registered\t$mx_record\t$display_status\n"
                        first_line=0
                    else
                        output_buffer+="\t\t$mx_record\t\n"
                    fi
                fi
            done <<< "$effective_result"
        fi
    fi
done < <(find "$ZONEDIR" -maxdepth 1 -type f -name '*.db' -print0)

# ==============================================================================
# PRINT FINAL TABLE
# ==============================================================================
echo "================================================================================"
if command -v column &> /dev/null; then
    echo -e "DOMAIN\tREGISTERED\tMX RECORD\tSTATUS" | column -t -s $'\t'
    echo "--------------------------------------------------------------------------------"
    if [[ -n "$output_buffer" ]]; then
        echo -e "$output_buffer" | column -t -s $'\t'
    else
        echo "(No matching zone files found in $ZONEDIR)"
    fi
else
    # Fallback when 'column' utility is not installed
    printf "%-32s %-12s %-25s %-12s\n" "DOMAIN" "REGISTERED" "MX RECORD" "STATUS"
    echo "--------------------------------------------------------------------------------"
    if [[ -n "$output_buffer" ]]; then
        while IFS=$'\t' read -r c_domain c_reg c_mx c_status; do
            printf "%-32s %-12s %-25s %-12s\n" "$c_domain" "$c_reg" "$c_mx" "$c_status"
        done <<< "$(echo -e "$output_buffer")"
    else
        echo "(No matching zone files found in $ZONEDIR)"
    fi
fi
echo "================================================================================"

# ==============================================================================
# SUMMARY & EXIT CODE
# ==============================================================================
echo "Total zones checked: $total_checked"
if [[ $diff_found -eq 0 ]]; then
    echo -e "${C_GREEN}Summary: All zones appear correct.${C_RESET}"
else
    echo -e "${C_YELLOW}Summary: Discrepancies found (Check ERROR/DESYNC/EXTERNAL_MX/NO_MX status).${C_RESET}"
fi
echo "Total execution time: ${SECONDS}s"

exit $diff_found
