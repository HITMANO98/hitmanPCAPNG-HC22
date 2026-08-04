#!/usr/bin/env bash
# ==============================================================================
# HITMAN PCAPNG/HC22 v4.1 ULTIMATE - Wireless Capture & Hash Auditing Suite
# Features: 3-Tier Aggressive Extraction, Quality Engine, Quick-Crack,
# Webhooks, Watchdog Daemon, Master CSV Sync & Enhanced TUI Layout
# ==============================================================================

set -eo pipefail

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Paths & Configuration ---
CONFIG_DIR="$HOME/.config/hitman_pcap"
CONFIG_FILE="$CONFIG_DIR/config.conf"
LOG_FILE="./hitman_activity.log"
CSV_DB="./hitman_master.csv"
ARCHIVE_DIR="./archived_pcaps"
TEMP_RAW_FILE="/tmp/hitman_raw_$$.hc22000"

mkdir -p "$CONFIG_DIR"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Trap for automatic temp file cleanup on signal or exit
cleanup() {
    rm -f /tmp/hitman_raw_*.hc22000 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# API Credentials
OHC_API_KEY="${OHC_API_KEY:-}"
PWNCRACK_KEY="${PWNCRACK_KEY:-}"
WPA_SEC_KEY="${WPA_SEC_KEY:-}"
HASHMOB_KEY="${HASHMOB_KEY:-}"
WIGLE_API_TOKEN="${WIGLE_API_TOKEN:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Runtime Flags
ENABLE_FILE_LOGGING="${ENABLE_FILE_LOGGING:-true}"
ENABLE_AUTO_ARCHIVE="${ENABLE_AUTO_ARCHIVE:-true}"
ENABLE_QUICK_CRACK="${ENABLE_QUICK_CRACK:-true}"
QUICK_CRACK_WORDLIST="${QUICK_CRACK_WORDLIST:-/usr/share/wordlists/rockyou.txt}"

# Service Toggles for Custom Mode
TOGGLE_WPASEC="true"
TOGGLE_PWNCRACK="true"
TOGGLE_OHC="true"
TOGGLE_HASHMOB="true"
TOGGLE_WIGLE="true"

# Initialize Master CSV Database
if [ ! -f "$CSV_DB" ]; then
    echo "Timestamp,BSSID,ESSID,Password,Source,Origin_File" > "$CSV_DB"
fi

# --- Logging System ---
log_msg() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    case "$level" in
        INFO)  echo -e " ${BLUE}[*]${NC} ${msg}" ;;
        OK)    echo -e " ${GREEN}[+]${NC} ${msg}" ;;
        WARN)  echo -e " ${YELLOW}[!]${NC} ${msg}" ;;
        ERR)   echo -e " ${RED}[✘]${NC} ${msg}" ;;
        DATA)  echo -e " ${CYAN}[^]${NC} ${msg}" ;;
        CRACK) echo -e " ${MAGENTA}${BOLD}[KEY FOUND]${NC} ${WHITE}${BOLD}${msg}${NC}" ;;
        *)     echo -e " ${msg}" ;;
    esac

    if [ "$ENABLE_FILE_LOGGING" = "true" ]; then
        echo "[$timestamp] [$level] $msg" | sed 's/\x1B\[[0-9;]*[a-zA-R]//g' >> "$LOG_FILE"
    fi
}

# --- Webhook Alert System ---
send_alert() {
    local title="$1"
    local message="$2"

    if [ -n "$DISCORD_WEBHOOK" ]; then
        local payload
        payload=$(jq -n --arg t "$title" --arg m "$message" '{"embeds": [{"title": $t, "description": $m, "color": 3066993}]}')
        curl -sS -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
    fi

    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        local text="*${title}*\n${message}"
        curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=Markdown" \
            -d "text=${text}" >/dev/null 2>&1 || true
    fi
}

# --- Visual UI Header & Dashboard ---
UI_WIDTH=62

repeat_char() {
    local char="$1" count="$2"
    printf '%*s' "$count" '' | tr ' ' "$char"
}

ui_line() {
    echo -e "${DIM}$(repeat_char '─' "$UI_WIDTH")${NC}"
}

ui_status() {
    local label="$1" state="$2"
    if [ "$state" = "true" ]; then
        printf "${GREEN}●${NC} %-15s ${GREEN}ENABLED${NC}" "$label"
    else
        printf "${RED}○${NC} %-15s ${DIM}DISABLED${NC}" "$label"
    fi
}

ui_dependency_status() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null && echo -e "${GREEN}● READY${NC}" || echo -e "${RED}○ MISSING${NC}"
}

print_banner() {
    clear
    echo -e "${RED}${BOLD}"
    echo '  ██╗  ██╗██╗████████╗███╗   ███╗██████╗ ███╗   ██╗'
    echo '  ██║  ██║██║╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║'
    echo '  ███████║██║   ██║   ██╔████╔██║███████║██╔██╗ ██║'
    echo '  ██╔══██║██║   ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║'
    echo '  ██║  ██║██║   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║'
    echo '  ╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝'
    echo -e "${CYAN}${BOLD}             PCAPNG / HC22000 ULTIMATE${NC}"
    echo -e "${WHITE}${BOLD}                    SUITE v4.1${NC}"
    ui_line
    echo -e " ${DIM}WIRELESS CAPTURE PROCESSING • RECOVERY • AUDITING${NC}"
    ui_line
}

draw_box_header() {
    local title="$1"
    echo -e "${CYAN}┌─[ ${WHITE}${BOLD}${title}${NC}${CYAN} ]$(repeat_char '─' $((UI_WIDTH - ${#title} - 5)))┐${NC}"
}

draw_box_footer() {
    echo -e "${CYAN}└$(repeat_char '─' $((UI_WIDTH - 2)))┘${NC}"
}

draw_status_panel() {
    echo -e "${CYAN}┌─[ ${WHITE}${BOLD}HC22 SYSTEM STATUS${NC}${CYAN} ]$(repeat_char '─' 42)┐${NC}"
    printf "${DIM}│${NC}  Engine          ${GREEN}● READY${NC}        "
    printf "Quick-Audit      "
    if [ "$ENABLE_QUICK_CRACK" = "true" ]; then echo -e "${GREEN}● ON${NC}       ${DIM}│${NC}"; else echo -e "${DIM}○ OFF${NC}      ${DIM}│${NC}"; fi
    printf "${DIM}│${NC}  Auto-Archive    "
    if [ "$ENABLE_AUTO_ARCHIVE" = "true" ]; then echo -e "${GREEN}● ON${NC}           Watchdog         ${CYAN}● READY${NC}    ${DIM}│${NC}"; else echo -e "${DIM}○ OFF${NC}          Watchdog         ${CYAN}● READY${NC}    ${DIM}│${NC}"; fi
    printf "${DIM}│${NC}  hcxpcapngtool   %b       curl             %b   ${DIM}│${NC}\n" "$(ui_dependency_status hcxpcapngtool)" "$(ui_dependency_status curl)"
    printf "${DIM}│${NC}  jq              %b       hashcat          %b   ${DIM}│${NC}\n" "$(ui_dependency_status jq)" "$(ui_dependency_status hashcat)"
    draw_box_footer
}

print_footer() {
    echo -e "${DIM} HC22 v4.1 │ ULTIMATE WIRELESS AUDITING SUITE │ Bash${NC}"
}

mask_key() {
    local key="$1"
    if [ -z "$key" ]; then
        echo -e "${RED}✘ Missing${NC}"
    elif [ ${#key} -gt 10 ]; then
        echo -e "${GREEN}✔ Configured (${key:0:4}...)${NC}"
    else
        echo -e "${GREEN}✔ Saved${NC}"
    fi
}

get_file_size() {
    local file="$1"
    if command -v du &>/dev/null; then
        du -sh "$file" 2>/dev/null | cut -f1
    else
        echo "N/A"
    fi
}

# --- Dependency Check ---
check_dependencies() {
    local required=(hcxpcapngtool curl jq)
    local missing_req=()

    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_req+=("$cmd")
        fi
    done

    if [ ${#missing_req[@]} -ne 0 ]; then
        echo -e "${RED}${BOLD}[!] Missing Required Package(s): ${missing_req[*]}${NC}\n"
        echo -e "${YELLOW}Please install dependencies using your package manager:${NC}"
        echo -e "  • Debian/Ubuntu/Kali/Parrot : ${CYAN}sudo apt install hcxtools curl jq${NC}"
        echo -e "  • Arch Linux/Manjaro        : ${CYAN}sudo pacman -S hcxtools curl jq${NC}"
        return 1
    fi
    return 0
}

# --- File Scanner & Interactive Table Selector ---
scan_files() {
    local ext="$1"
    shopt -s nullglob
    case "$ext" in
        raw)  FILES=(*.pcap *.cap *.pcapng) ;;
        hc22) FILES=(*.hc22000) ;;
        all)  FILES=(*.pcap *.cap *.pcapng *.hc22000) ;;
    esac
    shopt -u nullglob
}

display_file_list() {
    local -n file_arr=$1
    if [ ${#file_arr[@]} -eq 0 ]; then
        echo -e "${YELLOW}  (No matching capture files found in execution directory)${NC}"
        return 1
    fi

    echo -e "${DIM}┌────┬──────────────────────────────────┬───────────┬──────────────┐${NC}"
    printf "${DIM}│${NC} ${BOLD}%-2s${NC} ${DIM}│${NC} ${BOLD}%-32s${NC} ${DIM}│${NC} ${BOLD}%-9s${NC} ${DIM}│${NC} ${BOLD}%-12s${NC} ${DIM}│${NC}\n" "ID" "File Name" "Size" "Info/Hashes"
    echo -e "${DIM}├────┼──────────────────────────────────┼───────────┼──────────────┤${NC}"

    local idx=1
    for f in "${file_arr[@]}"; do
        local sz
        sz=$(get_file_size "$f")
        local extra=""
        if [[ "$f" == *.hc22000 ]]; then
            local lines
            lines=$(grep -c -v '^#' "$f" 2>/dev/null || echo "0")
            extra="${lines} line(s)"
        else
            extra="Raw PCAP"
        fi

        printf "${DIM}│${NC} %-2d   ${DIM}│${NC} %-32s ${DIM}│${NC} %-9s ${DIM}│${NC} %-12s ${DIM}│${NC}\n" "$idx" "${f:0:30}" "$sz" "$extra"
        ((idx++))
    done
    echo -e "${DIM}└────┴──────────────────────────────────┴───────────┴──────────────┘${NC}"
    return 0
}

select_files_interactive() {
    local -n src_arr=$1
    local -n dest_arr=$2
    dest_arr=()

    display_file_list src_arr || return 1

    echo -e "\n ${CYAN}Selection Options:${NC}"
    echo -e "   • Space-separated indices (e.g., ${BOLD}1 3 4${NC})"
    echo -e "   • Type ${BOLD}A${NC} or ${BOLD}ALL${NC} to select everything"
    echo -e "   • Type ${BOLD}0${NC} to cancel\n"

    echo -ne " ${YELLOW}Enter Choice ❯ ${NC}"
    read -r sel

    if [[ "$sel" == "0" ]]; then
        return 1
    elif [[ "${sel,,}" == "a" || "${sel,,}" == "all" ]]; then
        dest_arr=("${src_arr[@]}")
    else
        for num in $sel; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#src_arr[@]}" ]; then
                dest_arr+=("${src_arr[$((num-1))]}")
            else
                log_msg "WARN" "Invalid index '$num' ignored."
            fi
        done
    fi

    if [ ${#dest_arr[@]} -eq 0 ]; then
        log_msg "WARN" "No valid files selected."
        return 1
    fi

    echo -e "\n ${GREEN}[+] Selected ${#dest_arr[@]} file(s) for workflow.${NC}"
}

# --- 3-Tier Aggressive Conversion & Quality Engine ---
convert_and_filter_pcaps() {
    local -n pcaps_to_conv=$1
    local output_file="$2"

    if [ ${#pcaps_to_conv[@]} -eq 0 ]; then
        log_msg "WARN" "No capture files supplied for conversion."
        return 1
    fi

    rm -f "$TEMP_RAW_FILE"

    # --- Tier 1: Standard Extraction ---
    log_msg "INFO" "[Pass 1/3] Attempting standard handshake extraction..."
    hcxpcapngtool -o "$TEMP_RAW_FILE" "${pcaps_to_conv[@]}" >/dev/null 2>&1 || true

    # --- Tier 2: Aggressive Nonce Error Correction (8-bit) ---
    if [ ! -f "$TEMP_RAW_FILE" ] || [ ! -s "$TEMP_RAW_FILE" ]; then
        log_msg "WARN" "[Pass 1 Failed] Escalating to Tier 2: Nonce Error Correction (8-bit)..."
        hcxpcapngtool --nonce-error-corrections=8 -o "$TEMP_RAW_FILE" "${pcaps_to_conv[@]}" >/dev/null 2>&1 || true
    fi

    # --- Tier 3: Maximum Recovery (16-bit Nonce + Corrupted Frame Parsing) ---
    if [ ! -f "$TEMP_RAW_FILE" ] || [ ! -s "$TEMP_RAW_FILE" ]; then
        log_msg "WARN" "[Pass 2 Failed] Escalating to Tier 3: Maximum Aggressive Extraction (16-bit + Corrupted Recovery)..."
        hcxpcapngtool --nonce-error-corrections=16 --all -o "$TEMP_RAW_FILE" "${pcaps_to_conv[@]}" >/dev/null 2>&1 || true
    fi

    # Evaluation
    if [ ! -f "$TEMP_RAW_FILE" ] || [ ! -s "$TEMP_RAW_FILE" ]; then
        log_msg "ERR" "All 3 extraction passes failed. Capture contains no valid or salvageable EAPOL frames."
        return 1
    fi

    log_msg "OK" "Handshake data successfully extracted/salvaged!"

    # --- Quality Filtering & De-duplication Engine ---
    if command -v hcxhashtool &>/dev/null; then
        log_msg "INFO" "[Quality Engine] Filtering invalid hashes & stripping duplicates via hcxhashtool..."
        hcxhashtool -i "$TEMP_RAW_FILE" -o "$output_file" --remove-duplicates >/dev/null 2>&1 || cp "$TEMP_RAW_FILE" "$output_file"
        rm -f "$TEMP_RAW_FILE"
    else
        mv "$TEMP_RAW_FILE" "$output_file"
    fi

    local line_cnt
    line_cnt=$(grep -c -v '^#' "$output_file" 2>/dev/null || echo "0")
    log_msg "OK" "Pipeline compiled $line_cnt verified hash line(s) into -> $output_file"
    echo "$output_file"
}

# --- Local Quick-Crack Module ---
run_local_quick_crack() {
    local hc_file="$1"

    if [ "$ENABLE_QUICK_CRACK" != "true" ]; then return; fi
    if ! command -v hashcat &>/dev/null; then
        log_msg "WARN" "[Quick-Crack] Hashcat binary not found. Skipping local check."
        return
    fi
    if [ ! -f "$QUICK_CRACK_WORDLIST" ]; then
        log_msg "WARN" "[Quick-Crack] Wordlist '$QUICK_CRACK_WORDLIST' not found. Skipping."
        return
    fi

    log_msg "INFO" "[Quick-Crack] Executing local Hashcat dictionary pass..."
    local potfile="$CONFIG_DIR/hitman.potfile"
    local cracked_out="$CONFIG_DIR/cracked_temp.txt"
    rm -f "$cracked_out"

    hashcat -m 22000 "$hc_file" "$QUICK_CRACK_WORDLIST" \
        --potfile-path="$potfile" \
        --outfile="$cracked_out" \
        --outfile-format=2 \
        --quiet -w 3 >/dev/null 2>&1 || true

    if [ -f "$cracked_out" ] && [ -s "$cracked_out" ]; then
        while IFS= read -r password; do
            log_msg "CRACK" "Local Match Found! Password: $password"
            send_alert "Local Hashcat Hit!" "Target File: $hc_file\nCracked Password: \`$password\`"
            echo "$(date '+%Y-%m-%d %H:%M:%S'),N/A,N/A,$password,Local Hashcat,$hc_file" >> "$CSV_DB"
        done < "$cracked_out"
    else
        log_msg "INFO" "[Quick-Crack] No immediate wordlist hits."
    fi
    rm -f "$cracked_out"
}

# --- Service Upload Connectors ---
upload_ohc_v2() {
    local hc_file="$1"
    if [ "$TOGGLE_OHC" != "true" ] || [ -z "$OHC_API_KEY" ]; then
        log_msg "WARN" "[OnlineHashCrack] Skipped (Disabled or Missing Key)"
        return
    fi

    log_msg "INFO" "[OnlineHashCrack v2] Submitting $hc_file..."
    mapfile -t HASH_ARRAY < <(grep -v '^#' "$hc_file" | grep -v '^$')
    local total=${#HASH_ARRAY[@]}

    if [ "$total" -eq 0 ]; then
        log_msg "ERR" "[OnlineHashCrack] Zero valid hashes inside $hc_file"
        return
    fi

    local chunk_size=50
    for ((i=0; i<total; i+=chunk_size)); do
        local batch=("${HASH_ARRAY[@]:i:chunk_size}")
        local json_hashes
        json_hashes=$(printf '%s\n' "${batch[@]}" | jq -R . | jq -s .)

        PAYLOAD=$(jq -n \
            --arg key "$OHC_API_KEY" \
            --arg terms "yes" \
            --arg action "add_tasks" \
            --argjson algo 22000 \
            --argjson hashes "$json_hashes" \
            '{api_key: $key, agree_terms: $terms, action: $action, algo_mode: $algo, hashes: $hashes}')

        RESPONSE=$(curl -sS -X POST "https://api.onlinehashcrack.com/v2" -H "Content-Type: application/json" -d "$PAYLOAD")
        log_msg "OK" "[OnlineHashCrack] Status: $RESPONSE"
    done
}

upload_pwncrack() {
    local hc_file="$1"
    if [ "$TOGGLE_PWNCRACK" != "true" ] || [ -z "$PWNCRACK_KEY" ]; then
        log_msg "WARN" "[PwnCrack] Skipped (Disabled or Missing Key)"
        return
    fi

    log_msg "INFO" "[PwnCrack] Transmitting $hc_file..."
    RESPONSE=$(curl -sS -X POST "https://pwncrack.org/upload_handshake" -F "handshake=@$hc_file" -F "key=$PWNCRACK_KEY")
    log_msg "OK" "[PwnCrack] Status: $RESPONSE"
}

upload_wpasec_files() {
    local -n files_to_up=$1
    if [ "$TOGGLE_WPASEC" != "true" ] || [ -z "$WPA_SEC_KEY" ]; then
        log_msg "WARN" "[WPA-SEC] Skipped (Disabled or Missing Key)"
        return
    fi

    for f in "${files_to_up[@]}"; do
        log_msg "INFO" "[WPA-SEC] Uploading raw capture: $f"
        RESPONSE=$(curl -sS -X POST "https://wpa-sec.stanev.org/?api" --cookie "key=$WPA_SEC_KEY" -F "file=@$f")
        log_msg "OK" "[WPA-SEC] Status ($f): $RESPONSE"
    done
}

upload_hashmob() {
    local hc_file="$1"
    if [ "$TOGGLE_HASHMOB" != "true" ] || [ -z "$HASHMOB_KEY" ]; then
        log_msg "WARN" "[Hashmob.net] Skipped (Disabled or Missing Key)"
        return
    fi

    log_msg "INFO" "[Hashmob.net] Submitting $hc_file..."
    RESPONSE=$(curl -sS -X POST "https://hashmob.net/api/v2/hashes/upload" \
        -H "api-key: $HASHMOB_KEY" \
        -F "file=@$hc_file" \
        -F "algo_id=22000")
    log_msg "OK" "[Hashmob.net] Status: $RESPONSE"
}

upload_wigle() {
    local -n raw_files=$1
    if [ "$TOGGLE_WIGLE" != "true" ] || [ -z "$WIGLE_API_TOKEN" ]; then
        log_msg "WARN" "[WiGLE.net] Skipped (Disabled or Missing Key)"
        return
    fi

    for f in "${raw_files[@]}"; do
        log_msg "INFO" "[WiGLE.net] Submitting wardriving capture: $f"
        RESPONSE=$(curl -sS -X POST "https://wigle.net/api/v2/file/upload" \
            -H "Authorization: Basic $WIGLE_API_TOKEN" \
            -F "file=@$f")
        log_msg "OK" "[WiGLE.net] Status ($f): $RESPONSE"
    done
}

# --- Auto Archiver ---
archive_processed_files() {
    local -n files_to_arch=$1
    if [ "$ENABLE_AUTO_ARCHIVE" != "true" ] || [ ${#files_to_arch[@]} -eq 0 ]; then
        return
    fi

    mkdir -p "$ARCHIVE_DIR"
    log_msg "INFO" "Archiving ${#files_to_arch[@]} processed capture(s) -> $ARCHIVE_DIR"
    for f in "${files_to_arch[@]}"; do
        if [ -f "$f" ]; then
            mv "$f" "$ARCHIVE_DIR/"
        fi
    done
    log_msg "OK" "Archiving finished."
}

# --- Primary Workflows ---
run_express_pipeline() {
    print_banner
    draw_box_header "1-Click Express Pipeline Running"

    scan_files "raw"
    if [ ${#FILES[@]} -gt 0 ]; then
        log_msg "INFO" "Discovered ${#FILES[@]} raw capture file(s)."
        
        upload_wigle FILES
        upload_wpasec_files FILES

        local combined="combined_cleaned.hc22000"
        CONVERTED_FILE=$(convert_and_filter_pcaps FILES "$combined") || true

        if [ -n "$CONVERTED_FILE" ]; then
            run_local_quick_crack "$CONVERTED_FILE"
            upload_pwncrack "$CONVERTED_FILE"
            upload_ohc_v2 "$CONVERTED_FILE"
            upload_hashmob "$CONVERTED_FILE"
        fi

        send_alert "Hitman Pipeline Execution Complete" "Successfully processed ${#FILES[@]} raw capture(s)."
        archive_processed_files FILES
    else
        log_msg "WARN" "No raw captures found. Checking for pre-existing .hc22000 files..."
        scan_files "hc22"
        if [ ${#FILES[@]} -gt 0 ]; then
            for hc in "${FILES[@]}"; do
                run_local_quick_crack "$hc"
                upload_pwncrack "$hc"
                upload_ohc_v2 "$hc"
                upload_hashmob "$hc"
            done
        else
            log_msg "ERR" "No captures or .hc22000 files present in current directory."
        fi
    fi
    log_msg "OK" "Express Pipeline finished."
}

run_watchdog_daemon() {
    local watch_target="${1:-.}"
    print_banner
    draw_box_header "Automated Directory Watchdog Active"
    log_msg "INFO" "Monitoring directory: '$watch_target' for incoming captures..."

    if command -v inotifywait &>/dev/null; then
        inotifywait -m -e close_write,moved_to --format "%w%f" "$watch_target" | while read -r new_file; do
            if [[ "$new_file" =~ \.(pcap|cap|pcapng)$ ]]; then
                log_msg "OK" "[Watchdog Alert] Discovered new capture: $new_file"
                sleep 2
                run_express_pipeline
            fi
        done
    else
        log_msg "WARN" "inotifywait missing. Utilizing 15-second polling loop fallback."
        while true; do
            scan_files "raw"
            if [ ${#FILES[@]} -gt 0 ]; then
                log_msg "OK" "[Watchdog Alert] Discovered new raw captures."
                run_express_pipeline
            fi
            sleep 15
        done
    fi
}

run_custom_workflow_builder() {
    while true; do
        print_banner
        draw_box_header "Custom Workflow Builder & Service Matrix"
        
        echo -e "${DIM}│${NC} ${BOLD}CLOUD SERVICE MATRIX${NC}"
        echo -e "${DIM}│${NC}  [1] WPA-SEC          : $( [ "$TOGGLE_WPASEC" = "true" ] && echo -e "${GREEN}● ENABLED${NC}" || echo -e "${RED}○ DISABLED${NC}" )"
        echo -e "${DIM}│${NC}  [2] PwnCrack         : $( [ "$TOGGLE_PWNCRACK" = "true" ] && echo -e "${GREEN}● ENABLED${NC}" || echo -e "${RED}○ DISABLED${NC}" )"
        echo -e "${DIM}│${NC}  [3] OnlineHashCrack  : $( [ "$TOGGLE_OHC" = "true" ] && echo -e "${GREEN}● ENABLED${NC}" || echo -e "${RED}○ DISABLED${NC}" )"
        echo -e "${DIM}│${NC}  [4] Hashmob.net      : $( [ "$TOGGLE_HASHMOB" = "true" ] && echo -e "${GREEN}● ENABLED${NC}" || echo -e "${RED}○ DISABLED${NC}" )"
        echo -e "${DIM}│${NC}  [5] WiGLE.net        : $( [ "$TOGGLE_WIGLE" = "true" ] && echo -e "${GREEN}● ENABLED${NC}" || echo -e "${RED}○ DISABLED${NC}" )"
        echo -e "${DIM}│${NC}"
        echo -e "${DIM}│${NC} ${BOLD}WORKFLOW ACTIONS${NC}"
        echo -e "${DIM}│${NC}  [6] Select Raw PCAPs       ❯ Process & Submit"
        echo -e "${DIM}│${NC}  [7] Select .hc22000 Files  ❯ Submit to Active APIs"
        echo -e "${DIM}│${NC}  [0] Return to Main Menu"
        draw_box_footer
        echo -ne "\n ${YELLOW}${BOLD}HC22 ❯ ${NC}"
        read -r choice

        case "$choice" in
            1) TOGGLE_WPASEC=$([ "$TOGGLE_WPASEC" = "true" ] && echo "false" || echo "true") ;;
            2) TOGGLE_PWNCRACK=$([ "$TOGGLE_PWNCRACK" = "true" ] && echo "false" || echo "true") ;;
            3) TOGGLE_OHC=$([ "$TOGGLE_OHC" = "true" ] && echo "false" || echo "true") ;;
            4) TOGGLE_HASHMOB=$([ "$TOGGLE_HASHMOB" = "true" ] && echo "false" || echo "true") ;;
            5) TOGGLE_WIGLE=$([ "$TOGGLE_WIGLE" = "true" ] && echo "false" || echo "true") ;;
            6)
                scan_files "raw"
                local SELECTED_RAW=()
                if select_files_interactive FILES SELECTED_RAW; then
                    upload_wigle SELECTED_RAW
                    upload_wpasec_files SELECTED_RAW
                    local custom_hc="custom_selection.hc22000"
                    CONV=$(convert_and_filter_pcaps SELECTED_RAW "$custom_hc") || true
                    if [ -n "$CONV" ]; then
                        run_local_quick_crack "$CONV"
                        upload_pwncrack "$CONV"
                        upload_ohc_v2 "$CONV"
                        upload_hashmob "$CONV"
                    fi
                    archive_processed_files SELECTED_RAW
                fi
                read -rp "Press Enter to continue..."
                ;;
            7)
                scan_files "hc22"
                local SELECTED_HC=()
                if select_files_interactive FILES SELECTED_HC; then
                    for hc_item in "${SELECTED_HC[@]}"; do
                        run_local_quick_crack "$hc_item"
                        upload_pwncrack "$hc_item"
                        upload_ohc_v2 "$hc_item"
                        upload_hashmob "$hc_item"
                    done
                fi
                read -rp "Press Enter to continue..."
                ;;
            0) break ;;
            *) echo -e " ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

# --- Settings & Credentials Manager ---
manage_settings() {
    while true; do
        print_banner
        draw_box_header "Configuration & API Credentials"
        
        echo -e " ${BOLD}API Keys:${NC}"
        echo -e "  [1] OHC API Key        : $(mask_key "$OHC_API_KEY")"
        echo -e "  [2] PwnCrack Key       : $(mask_key "$PWNCRACK_KEY")"
        echo -e "  [3] WPA-SEC Key        : $(mask_key "$WPA_SEC_KEY")"
        echo -e "  [4] Hashmob API Key    : $(mask_key "$HASHMOB_KEY")"
        echo -e "  [5] WiGLE Auth Token   : $(mask_key "$WIGLE_API_TOKEN")"
        echo -e "\n ${BOLD}Webhooks & Alerting:${NC}"
        echo -e "  [6] Discord Webhook    : $(mask_key "$DISCORD_WEBHOOK")"
        echo -e "  [7] Telegram Bot Token : $(mask_key "$TELEGRAM_BOT_TOKEN")"
        echo -e "  [8] Telegram Chat ID   : $(mask_key "$TELEGRAM_CHAT_ID")"
        echo -e "\n ${BOLD}Automation Settings:${NC}"
        echo -e "  [9] Quick-Crack Precheck: ${GREEN}${ENABLE_QUICK_CRACK}${NC}"
        echo -e "  [10] Auto-Archive PCAPs : ${GREEN}${ENABLE_AUTO_ARCHIVE}${NC}"
        echo -e "  [0] Return to Main Menu\n"
        echo -ne " ${YELLOW}Select Option ❯ ${NC}"
        read -r choice

        case "$choice" in
            1) echo -ne "\nEnter OHC API Key: "; read -r OHC_API_KEY ;;
            2) echo -ne "\nEnter PwnCrack Key: "; read -r PWNCRACK_KEY ;;
            3) echo -ne "\nEnter WPA-SEC Key: "; read -r WPA_SEC_KEY ;;
            4) echo -ne "\nEnter Hashmob API Key: "; read -r HASHMOB_KEY ;;
            5) echo -ne "\nEnter WiGLE Base64 Auth Token: "; read -r WIGLE_API_TOKEN ;;
            6) echo -ne "\nEnter Discord Webhook URL: "; read -r DISCORD_WEBHOOK ;;
            7) echo -ne "\nEnter Telegram Bot Token: "; read -r TELEGRAM_BOT_TOKEN ;;
            8) echo -ne "\nEnter Telegram Chat ID: "; read -r TELEGRAM_CHAT_ID ;;
            9) ENABLE_QUICK_CRACK=$([ "$ENABLE_QUICK_CRACK" = "true" ] && echo "false" || echo "true") ;;
            10) ENABLE_AUTO_ARCHIVE=$([ "$ENABLE_AUTO_ARCHIVE" = "true" ] && echo "false" || echo "true") ;;
            0) break ;;
            *) echo -e " ${RED}Invalid option.${NC}"; sleep 1 ;;
        esac

        cat << EOF > "$CONFIG_FILE"
OHC_API_KEY="$OHC_API_KEY"
PWNCRACK_KEY="$PWNCRACK_KEY"
WPA_SEC_KEY="$WPA_SEC_KEY"
HASHMOB_KEY="$HASHMOB_KEY"
WIGLE_API_TOKEN="$WIGLE_API_TOKEN"
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
ENABLE_FILE_LOGGING="$ENABLE_FILE_LOGGING"
ENABLE_AUTO_ARCHIVE="$ENABLE_AUTO_ARCHIVE"
ENABLE_QUICK_CRACK="$ENABLE_QUICK_CRACK"
QUICK_CRACK_WORDLIST="$QUICK_CRACK_WORDLIST"
EOF
    done
}

# --- Main Program Loop ---
main() {
    check_dependencies || exit 1

    case "$1" in
        -a|--auto)   run_express_pipeline ;;
        -w|--watch)  run_watchdog_daemon "${2:-.}" ;;
        -c|--config) manage_settings ;;
        -h|--help)
            echo "hitmanPCAPNG/HC22 v4.1 Usage Options:"
            echo "  -a, --auto      Run Express Pipeline non-interactively"
            echo "  -w, --watch [dir] Launch Directory Watchdog Daemon"
            echo "  -c, --config    Open Settings & Credentials Menu"
            echo "  -h, --help      Display help options"
            ;;
        *)
            while true; do
                print_banner
                draw_status_panel
                echo
                draw_box_header "MAIN OPERATIONS"
                echo -e "${DIM}│${NC}  ${RED}${BOLD}[1]${NC} ⚡ ${WHITE}${BOLD}EXPRESS PIPELINE${NC}  ${DIM}Automatic extract → audit → submit → archive${NC}"
                echo -e "${DIM}│${NC}  ${CYAN}${BOLD}[2]${NC} 👁 ${WHITE}${BOLD}WATCHDOG${NC}           ${DIM}Monitor a directory for incoming captures${NC}"
                echo -e "${DIM}│${NC}  ${MAGENTA}${BOLD}[3]${NC} 🛠 ${WHITE}${BOLD}WORKFLOW BUILDER${NC}   ${DIM}Granular file and service selection${NC}"
                echo -e "${DIM}│${NC}  ${BLUE}${BOLD}[4]${NC} 📂 ${WHITE}${BOLD}FILE INSPECTOR${NC}     ${DIM}Inspect captures and HC22000 files${NC}"
                echo -e "${DIM}│${NC}  ${YELLOW}${BOLD}[5]${NC} ⚙ ${WHITE}${BOLD}CONFIGURATION${NC}      ${DIM}APIs • Webhooks • Automation${NC}"
                echo -e "${DIM}│${NC}  ${DIM}[0]${NC} ${WHITE}EXIT${NC}               ${DIM}Close HC22${NC}"
                draw_box_footer
                echo
                print_footer
                echo -ne "\n ${YELLOW}${BOLD}HC22 ❯ ${NC}"
                read -r opt
                case "$opt" in
                    1) run_express_pipeline; read -rp "Press Enter to continue..." ;;
                    2) run_watchdog_daemon "."; read -rp "Press Enter to continue..." ;;
                    3) run_custom_workflow_builder ;;
                    4) scan_files "all"; display_file_list FILES || true; read -rp "Press Enter to continue..." ;;
                    5) manage_settings ;;
                    0) echo -e " ${GREEN}Goodbye!${NC}"; exit 0 ;;
                    *) echo -e " ${RED}Invalid option.${NC}"; sleep 1 ;;
                esac
            done
            ;;
    esac
}

main "$@"
