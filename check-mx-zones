#!/usr/bin/env bash
set -o pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Define your nameservers here
NS1="ns1.server.tld"
NS2="ns2.server.tld"

# Directory containing Bind/Named .db zone files
ZONEDIR="/var/named"
# ==============================================================================

diff_found=0
output_buffer=""
SECONDS=0  # Start timer

# Check for required dependencies
if ! command -v dig &> /dev/null || ! command -v whois &> /dev/null; then
    echo "Error: 'dig' and 'whois' are required. Please install bind-utils and whois."
    exit 1
fi

echo "Starting DNS Zone check..."
echo "Scanning directory: $ZONEDIR"

# Loop through .db files in the zone directory
while IFS= read -r -d '' f; do
    # Extract domain name from filename (remove path and .db extension)
    domain="${f##*/}"
    domain="${domain%.db}"

    # Only process domains where the local zone file explicitly defines 
    # an MX record pointing to 'mail.DOMAIN.'
    if grep -Eq "^[[:space:]]*([[:alnum:]_.-]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+[0-9]+[[:space:]]+mail\.${domain}\.[[:space:]]*$" "$f"; then
        
        echo "Checking: $domain"

        # Query both nameservers
        ns1_result="$(dig +short @"$NS1" "$domain" MX | sort)"
        ns2_result="$(dig +short @"$NS2" "$domain" MX | sort)"

        # 1. Compare Nameservers & Check for specific 'mail.domain' record with priority 0
        # Note: Adjust priority grep if your standard is not 0
        if [ "$ns1_result" = "$ns2_result" ] && grep -qi "^0[[:space:]]\+mail\.${domain}\.$" <<<"$ns1_result"; then
            status="OK"
        else
            status="ERROR"
            diff_found=1
        fi

        # 2. Check if domain is registered via WHOIS
        # Note: Frequent whois lookups may trigger rate limiting from registrars
        if whois "$domain" 2>/dev/null | grep -iq 'No match'; then
            registered="NO"
        else
            registered="YES"
        fi

        # Format output for the table (handling multiple MX lines if necessary)
        first_line=1
        while IFS= read -r mx_record; do
            if [[ -n "$mx_record" ]]; then
                if [[ $first_line -eq 1 ]]; then
                    output_buffer+="$domain\t$registered\t$mx_record\t$status\n"
                    first_line=0
                else
                    output_buffer+="\t\t$mx_record\t\n"
                fi
            fi
        done <<< "$ns1_result"
    fi
done < <(find "$ZONEDIR" -maxdepth 1 -type f -name '*.db' -print0)

# Print Final Table
echo
echo "================================================================================"
echo -e "DOMAIN\tREGISTERED\tMX RECORD\tSTATUS" | column -t -s $'\t'
echo "================================================================================"
echo -e "$output_buffer" | column -t -s $'\t'
echo "================================================================================"

# Summary and Exit Code
if [ $diff_found -eq 0 ]; then
    echo "Summary: All zones appear correct."
else
    echo "Summary: Discrepancies found (Check ERROR status)."
fi

echo "Total execution time: ${SECONDS}s"

exit $diff_found
