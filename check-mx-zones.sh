#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Named Check MX Zones v1.2.0                                             ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: contato@perciocastelo.com.br                                   ║
# ║   Website: https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Auditoria de consistência e sincronização de zonas DNS MX      ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -o pipefail

# ==============================================================================
# CONFIGURATION & DEFAULTS
# ==============================================================================
VERSION="1.2.0"
ZONEDIR="/var/named"
SINGLE_DOMAIN=""
NS1=""
NS2=""
USE_AUTH_NS=false
TIMEOUT=2
TRIES=1
JOBS=5
SKIP_WHOIS=false
CHECK_ONLY_LOCAL=true
ONLY_ISSUES=false
OUTPUT_FORMAT="table"
VERBOSE=false
USE_COLOR=true

# Temporary directory for parallel processing and atomic outputs
TMP_DIR=""
cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Disable colors if stdout is not a terminal
if [[ ! -t 1 ]]; then
    USE_COLOR=false
fi

setup_colors() {
    if [[ "$USE_COLOR" = true && "$OUTPUT_FORMAT" = "table" ]]; then
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
}

# ==============================================================================
# USAGE
# ==============================================================================
usage() {
    cat << EOF
Named Check MX Zones v${VERSION}

Uso: $(basename "$0") [OPÇÕES]

Opções de Escopo e Diretório:
  -d, --dir DIR          Diretório com arquivos .db do BIND/Named (padrão: /var/named)
  -D, --domain DOMÍNIO   Verificar um domínio único ou arquivo de zona específico
  -a, --all              Verificar todos os registros MX, não apenas mail.<domínio>

Opções de Servidores DNS & Rede:
  -1, --ns1 SERVIDOR     Servidor DNS primário para consulta (padrão: auto-detectado ou 1.1.1.1)
  -2, --ns2 SERVIDOR     Servidor DNS secundário para consulta (padrão: auto-detectado ou 8.8.8.8)
  --auth, --authoritative Consultar os servidores NS autoritativos delegados de cada domínio
  -t, --timeout SEG      Timeout de consulta DNS por servidor em segundos (padrão: 2)
  -j, --jobs NUM         Número de tarefas paralelas concorrentes (padrão: 5, 1=sequencial)
  -w, --skip-whois       Pular consultas WHOIS de registro para varredura ultrarrápida

Opções de Saída e Relatório:
  -o, --output FORMATO   Formato de saída: table (padrão), json, csv
  -e, --only-issues      Exibir apenas domínios com divergências (DESYNC, NO_MX, EXTERNAL_MX, etc.)
  -v, --verbose          Exibir log detalhado de cada checagem no stderr
  --no-color             Desativar cores na saída de terminal
  -h, --help             Exibir este menu de ajuda e sair

Exemplos:
  $(basename "$0")
  $(basename "$0") -j 10 --skip-whois -o json > audit.json
  $(basename "$0") -D exemplo.com.br
  $(basename "$0") -e -o table
  $(basename "$0") --auth --all
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
        -D|--domain)
            SINGLE_DOMAIN="$2"; shift 2 ;;
        -1|--ns1)
            NS1="$2"; shift 2 ;;
        -2|--ns2)
            NS2="$2"; shift 2 ;;
        --auth|--authoritative)
            USE_AUTH_NS=true; shift ;;
        -t|--timeout)
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
                echo "Erro: --timeout deve ser um número inteiro positivo." >&2
                exit 1
            fi
            TIMEOUT="$2"; shift 2 ;;
        -j|--jobs)
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [[ "$2" -lt 1 ]]; then
                echo "Erro: --jobs deve ser um número inteiro positivo." >&2
                exit 1
            fi
            JOBS="$2"; shift 2 ;;
        -w|--skip-whois)
            SKIP_WHOIS=true; shift ;;
        -a|--all)
            CHECK_ONLY_LOCAL=false; shift ;;
        -e|--only-issues)
            ONLY_ISSUES=true; shift ;;
        -o|--output)
            case "$2" in
                table|json|csv) OUTPUT_FORMAT="$2" ;;
                *) echo "Erro: Formato de saída inválido '$2'. Use table, json ou csv." >&2; exit 1 ;;
            esac
            shift 2 ;;
        -v|--verbose)
            VERBOSE=true; shift ;;
        --no-color)
            USE_COLOR=false; shift ;;
        -h|--help)
            usage ;;
        *)
            echo "Erro: Opção desconhecida '$1'" >&2
            usage ;;
    esac
done

setup_colors

# ==============================================================================
# AUTO-DETECT NAMESERVERS
# ==============================================================================
if [[ "$USE_AUTH_NS" = false && ( -z "$NS1" || -z "$NS2" ) ]]; then
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
# DEPENDENCIES CHECK
# ==============================================================================
if ! command -v dig &> /dev/null; then
    echo "Erro: Utilitário 'dig' não encontrado. Instale bind-utils (RHEL/Alma) ou dnsutils (Debian/Ubuntu)." >&2
    exit 1
fi

if [[ "$SKIP_WHOIS" = false ]] && ! command -v whois &> /dev/null; then
    [[ "$VERBOSE" = true ]] && echo "Aviso: Utilitário 'whois' não encontrado. Desativando verificação WHOIS." >&2
    SKIP_WHOIS=true
fi

# ==============================================================================
# PREPARE DOMAIN LIST
# ==============================================================================
TMP_DIR="$(mktemp -d -t check-mx-zones.XXXXXX)"
RESULTS_FILE="$TMP_DIR/results.tsv"
touch "$RESULTS_FILE"

declare -a TARGET_ZONES=()

if [[ -n "$SINGLE_DOMAIN" ]]; then
    # Clean possible .db suffix
    d_clean="${SINGLE_DOMAIN##*/}"
    d_clean="${d_clean%.db}"
    # Look for candidate file
    if [[ -f "$SINGLE_DOMAIN" ]]; then
        TARGET_ZONES+=("$SINGLE_DOMAIN")
    elif [[ -f "${ZONEDIR}/${d_clean}.db" ]]; then
        TARGET_ZONES+=("${ZONEDIR}/${d_clean}.db")
    elif [[ -f "${ZONEDIR}/${SINGLE_DOMAIN}" ]]; then
        TARGET_ZONES+=("${ZONEDIR}/${SINGLE_DOMAIN}")
    else
        # Virtual zone without local file
        TARGET_ZONES+=("__VIRTUAL__:${d_clean}")
    fi
else
    if [[ ! -d "$ZONEDIR" ]]; then
        echo "Erro: Diretório de zonas '$ZONEDIR' não encontrado." >&2
        exit 1
    fi
    while IFS= read -r -d '' f; do
        bname="${f##*/}"
        d_name="${bname%.db}"
        case "$d_name" in
            named.ca|named.empty|named.localhost|named.loopback|named.broadcast|named.local|named.ip6.local|named.zero|localdomain|localhost)
                continue
                ;;
        esac
        TARGET_ZONES+=("$f")
    done < <(find "$ZONEDIR" -maxdepth 1 -type f -name '*.db' -print0)
fi

if [[ ${#TARGET_ZONES[@]} -eq 0 ]]; then
    if [[ "$OUTPUT_FORMAT" = "json" ]]; then
        echo '{"version":"'"$VERSION"'","total_checked":0,"issues_found":0,"execution_time_seconds":0,"results":[]}'
    elif [[ "$OUTPUT_FORMAT" = "csv" ]]; then
        echo "domain,registered,mx_record,status"
    else
        echo "Nenhum arquivo de zona correspondente encontrado em '$ZONEDIR'."
    fi
    exit 0
fi

# ==============================================================================
# WORKER FUNCTION FOR A SINGLE DOMAIN
# ==============================================================================
check_single_domain() {
    local target_item="$1"
    local domain=""
    local zone_file=""
    local is_virtual=false

    if [[ "$target_item" == __VIRTUAL__:* ]]; then
        domain="${target_item#__VIRTUAL__:}"
        is_virtual=true
    else
        zone_file="$target_item"
        domain="${zone_file##*/}"
        domain="${domain%.db}"
    fi

    local escaped_domain
    escaped_domain="$(printf '%s\n' "$domain" | sed 's/[^^]/[&]/g; s/\^/\\^/g')"

    # If reading local zone file, check MX filter
    if [[ "$is_virtual" = false && -f "$zone_file" ]]; then
        local should_check=false
        # Filter comments and match MX lines
        if [[ "$CHECK_ONLY_LOCAL" = true ]]; then
            if sed -e 's/;.*$//' "$zone_file" | grep -E -q "^[[:space:]]*(@|[[:alnum:]_.-]+)?[[:space:]]+([0-9]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+[0-9]+[[:space:]]+(mail\.${escaped_domain}\.?|mail[[:space:]]*$)" 2>/dev/null; then
                should_check=true
            fi
        else
            if sed -e 's/;.*$//' "$zone_file" | grep -E -q "^[[:space:]]*(@|[[:alnum:]_.-]+)?[[:space:]]+([0-9]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+" 2>/dev/null; then
                should_check=true
            fi
        fi

        if [[ "$should_check" = false ]]; then
            return 0
        fi
    fi

    [[ "$VERBOSE" = true ]] && echo "[$(date +'%H:%M:%S')] Verificando: $domain" >&2

    # Determine nameservers to query
    local query_ns1="$NS1"
    local query_ns2="$NS2"

    if [[ "$USE_AUTH_NS" = true ]]; then
        mapfile -t auth_ns_list < <(dig +time="$TIMEOUT" +tries="$TRIES" +short NS "$domain" 2>/dev/null | grep -E '^[a-zA-Z0-9.-]+\.?$' | head -n 2)
        if [[ -n "${auth_ns_list[0]:-}" ]]; then
            query_ns1="${auth_ns_list[0]%.}"
        else
            query_ns1="$NS1"
        fi
        if [[ -n "${auth_ns_list[1]:-}" ]]; then
            query_ns2="${auth_ns_list[1]%.}"
        else
            query_ns2="$NS2"
        fi
    fi

    # DNS queries
    local ns1_result ns2_result
    ns1_result="$(dig +time="$TIMEOUT" +tries="$TRIES" +short @"$query_ns1" "$domain" MX 2>/dev/null | sed -e 's/[[:space:]]\+/ /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort)"
    ns2_result="$(dig +time="$TIMEOUT" +tries="$TRIES" +short @"$query_ns2" "$domain" MX 2>/dev/null | sed -e 's/[[:space:]]\+/ /g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort)"

    # Status classification
    local status="OK"
    local is_issue=0

    if [[ -z "$ns1_result" && -z "$ns2_result" ]]; then
        status="NO_MX"
        is_issue=1
    elif [[ "$ns1_result" != "$ns2_result" ]]; then
        status="DESYNC"
        is_issue=1
    elif echo "$ns1_result" | grep -E -qi "[0-9]+[[:space:]]+mail\.${escaped_domain}\.?"; then
        status="OK"
    else
        if [[ "$CHECK_ONLY_LOCAL" = true ]]; then
            status="EXTERNAL_MX"
            is_issue=1
        else
            status="OK"
        fi
    fi

    # WHOIS check
    local registered="SKIP"
    if [[ "$SKIP_WHOIS" = false ]]; then
        local whois_out
        whois_out="$(timeout 5 whois "$domain" 2>/dev/null || true)"
        if [[ -z "$whois_out" ]]; then
            registered="TIMEOUT"
        elif echo "$whois_out" | grep -E -iq '(no match|not found|no data found|status:\s*free|domain not found|is free|available for registration)'; then
            registered="NO"
            is_issue=1
            status="NOT_REGISTERED"
        else
            registered="YES"
        fi
    fi

    local effective_mx="${ns1_result:-$ns2_result}"
    effective_mx="${effective_mx//$'\n'/; }"
    [[ -z "$effective_mx" ]] && effective_mx="(none)"

    # Append atomic record to RESULTS_FILE: domain \t registered \t mx_records \t status \t is_issue
    printf '%s\t%s\t%s\t%s\t%d\n' "$domain" "$registered" "$effective_mx" "$status" "$is_issue" >> "$RESULTS_FILE"
}

# ==============================================================================
# EXECUTION ORCHESTRATION (PARALLEL / SEQUENTIAL)
# ==============================================================================
SECONDS=0

if [[ "$OUTPUT_FORMAT" = "table" ]]; then
    echo -e "${C_BOLD}Starting Named Check MX Zones (v${VERSION})...${C_RESET}"
    echo "Diretório de Zonas: ${ZONEDIR}"
    [[ -n "$SINGLE_DOMAIN" ]] && echo "Alvo Único:         ${SINGLE_DOMAIN}"
    echo "Nameserver 1:       ${NS1:-auto/auth}"
    echo "Nameserver 2:       ${NS2:-auto/auth}"
    echo "Modo Autoritativo:  $([[ "$USE_AUTH_NS" = true ]] && echo "Ativado" || echo "Desativado")"
    echo "DNS Timeout:        ${TIMEOUT}s"
    echo "Concorrência:       ${JOBS} threads simultâneas"
    echo "Filtro WHOIS:       $([[ "$SKIP_WHOIS" = true ]] && echo "Desativado" || echo "Ativado")"
    echo "Filtro de Escopo:   $([[ "$CHECK_ONLY_LOCAL" = true ]] && echo "Apenas mail.<dominio> local" || echo "Todos os MX")"
    [[ "$ONLY_ISSUES" = true ]] && echo "Exibição:           Apenas discrepâncias (--only-issues)"
    echo
fi

# Run with concurrency limiter
if [[ "$JOBS" -le 1 ]]; then
    for target in "${TARGET_ZONES[@]}"; do
        check_single_domain "$target"
    done
else
    for target in "${TARGET_ZONES[@]}"; do
        check_single_domain "$target" &
        while [[ $(jobs -r -p | wc -l) -ge "$JOBS" ]]; do
            sleep 0.05
        done
    done
    wait
fi

# ==============================================================================
# RENDER OUTPUTS
# ==============================================================================
total_checked=0
issues_count=0

if [[ -f "$RESULTS_FILE" ]]; then
    total_checked=$(wc -l < "$RESULTS_FILE" | tr -d ' ')
fi

# Count issues
if [[ -f "$RESULTS_FILE" ]]; then
    issues_count=$(awk -F'\t' '$5 == 1 { count++ } END { print count+0 }' "$RESULTS_FILE")
fi

case "$OUTPUT_FORMAT" in
    json)
        # Generate valid JSON structure
        python3 -c "
import sys, json, os

results = []
issues = 0
total = 0

results_file = sys.argv[1]
only_issues = sys.argv[2] == 'true'
version = sys.argv[3]
duration = float(sys.argv[4])

if os.path.exists(results_file):
    with open(results_file, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            parts = line.rstrip('\r\n').split('\t')
            if len(parts) >= 5:
                domain, registered, mx_raw, status, is_issue = parts[0], parts[1], parts[2], parts[3], int(parts[4])
                total += 1
                if is_issue:
                    issues += 1
                if only_issues and not is_issue:
                    continue
                mx_list = [m.strip() for m in mx_raw.split(';') if m.strip()] if mx_raw != '(none)' else []
                results.append({
                    'domain': domain,
                    'registered': registered,
                    'mx_records': mx_list,
                    'status': status,
                    'has_issue': bool(is_issue)
                })

payload = {
    'version': version,
    'total_checked': total,
    'issues_found': issues,
    'execution_time_seconds': round(duration, 2),
    'results': results
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
" "$RESULTS_FILE" "$ONLY_ISSUES" "$VERSION" "$SECONDS"
        ;;

    csv)
        echo "domain,registered,mx_record,status,has_issue"
        if [[ -f "$RESULTS_FILE" ]]; then
            while IFS=$'\t' read -r domain registered mx status is_issue; do
                if [[ "$ONLY_ISSUES" = true && "$is_issue" -eq 0 ]]; then
                    continue
                fi
                # Escape commas/quotes in mx
                clean_mx="${mx//\"/\"\"}"
                echo "${domain},${registered},\"${clean_mx}\",${status},${is_issue}"
            done < "$RESULTS_FILE"
        fi
        ;;

    table|*)
        output_table=""
        if [[ -f "$RESULTS_FILE" ]]; then
            while IFS=$'\t' read -r domain registered mx status is_issue; do
                if [[ "$ONLY_ISSUES" = true && "$is_issue" -eq 0 ]]; then
                    continue
                fi

                # Colorize status
                display_status="$status"
                if [[ "$USE_COLOR" = true ]]; then
                    case "$status" in
                        OK)             display_status="${C_GREEN}OK${C_RESET}" ;;
                        EXTERNAL_MX)    display_status="${C_YELLOW}EXTERNAL_MX${C_RESET}" ;;
                        DESYNC)         display_status="${C_RED}DESYNC${C_RESET}" ;;
                        NO_MX)          display_status="${C_RED}NO_MX${C_RESET}" ;;
                        NOT_REGISTERED) display_status="${C_RED}NOT_REGISTERED${C_RESET}" ;;
                        *)              display_status="${C_RED}${status}${C_RESET}" ;;
                    esac
                fi

                # Expand multiple MX entries with neat indents if needed
                IFS=';' read -ra mx_arr <<< "$mx"
                first=true
                for m in "${mx_arr[@]}"; do
                    m_clean="$(echo "$m" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                    if [[ "$first" = true ]]; then
                        output_table+="${domain}\t${registered}\t${m_clean}\t${display_status}\n"
                        first=false
                    else
                        output_table+="\t\t${m_clean}\t\n"
                    fi
                done
            done < "$RESULTS_FILE"
        fi

        echo "================================================================================"
        if command -v column &> /dev/null; then
            echo -e "DOMAIN\tREGISTERED\tMX RECORD\tSTATUS" | column -t -s $'\t'
            echo "--------------------------------------------------------------------------------"
            if [[ -n "$output_table" ]]; then
                echo -e "$output_table" | column -t -s $'\t'
            else
                echo "(Nenhum registro encontrado correspondente aos critérios)"
            fi
        else
            printf "%-32s %-12s %-25s %-12s\n" "DOMAIN" "REGISTERED" "MX RECORD" "STATUS"
            echo "--------------------------------------------------------------------------------"
            if [[ -n "$output_table" ]]; then
                while IFS=$'\t' read -r c_domain c_reg c_mx c_status; do
                    printf "%-32s %-12s %-25s %-12s\n" "$c_domain" "$c_reg" "$c_mx" "$c_status"
                done <<< "$(echo -e "$output_table")"
            else
                echo "(Nenhum registro encontrado correspondente aos critérios)"
            fi
        fi
        echo "================================================================================"

        echo "Total de zonas auditadas: $total_checked"
        if [[ $issues_count -eq 0 ]]; then
            echo -e "${C_GREEN}Resumo: Todas as zonas estão corretas e sincronizadas.${C_RESET}"
        else
            echo -e "${C_YELLOW}Resumo: Encontradas $issues_count divergência(s) (verifique STATUS acima).${C_RESET}"
        fi
        echo "Tempo total de execução: ${SECONDS}s"
        ;;
esac

exit "$issues_count"
