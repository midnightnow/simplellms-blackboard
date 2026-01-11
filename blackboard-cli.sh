#!/bin/bash
# SimpleLLMs Blackboard CLI - v1.1.0 (P0 Hardened)
# Command-line interface for managing blackboard entries
#
# Security Fixes (Red Zen P0):
# - File locking for concurrent write safety
# - Input validation and sanitization
# - JSON injection protection via jq --arg
#
# Usage:
#   blackboard list                    - List all entries
#   blackboard add "VIOLATION"         - Add new entry
#   blackboard check                   - Show stats
#   blackboard violations [--last 24h] - Show recent violations
#   blackboard search "query"          - Search entries
#   blackboard export                  - Export to CSV

set -euo pipefail

# Configuration
BLACKBOARD_DIR="${BLACKBOARD_DIR:-$HOME/Projects/simplellms-blackboard}"
BLACKBOARD_FILE="$BLACKBOARD_DIR/blackboard.json"
DASHBOARD_FILE="$BLACKBOARD_DIR/dashboard.html"
LOCK_DIR="$BLACKBOARD_DIR/.blackboard.lock"
LOCK_TIMEOUT=10
MAX_VIOLATION_LENGTH=200

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Portable file locking using mkdir (atomic on all filesystems)
acquire_lock() {
    local attempts=0
    local max_attempts=$((LOCK_TIMEOUT * 10))

    # Check for stale lock first
    if [[ -d "$LOCK_DIR" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -rf "$LOCK_DIR"
        fi
    fi

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Error: Could not acquire lock after ${LOCK_TIMEOUT}s${NC}" >&2
            return 1
        fi
        sleep 0.1
    done

    echo $$ > "$LOCK_DIR/pid"
    # P1 fix: Handle SIGINT/SIGTERM for lock cleanup
    trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM
    return 0
}

release_lock() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# Sanitize input for JSON safety
sanitize_input() {
    local input="$1"
    local max_len="${2:-$MAX_VIOLATION_LENGTH}"

    echo "$input" | \
        tr -d '\000-\011\013-\037' | \
        sed 's/\\/\\\\/g; s/"/\\"/g' | \
        head -c "$max_len"
}

# Check dependencies
check_deps() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}" >&2
        exit 1
    fi
}

# Initialize blackboard if needed
init_blackboard() {
    if [[ ! -f "$BLACKBOARD_FILE" ]]; then
        echo '{"version":"1.0.0","meta":{"title":"SimpleLLMs Blackboard","totalEntries":0,"lastUpdated":""},"entries":[]}' > "$BLACKBOARD_FILE"
        chmod 600 "$BLACKBOARD_FILE"
    fi
}

# Show help
show_help() {
    cat << 'HELP'
SimpleLLMs Blackboard CLI v1.1.0

USAGE:
    blackboard <command> [options]

COMMANDS:
    list                    List all blackboard entries
    add <violation>         Add a new entry (without "I WILL NOT")
    check                   Show blackboard statistics
    violations [--last Nh]  Show violations (optionally from last N hours)
    search <query>          Search entries by keyword
    agent <name>            Filter entries by agent (ralph, bart, lisa, marge, homer)
    delete <id>             Delete an entry by ID
    export [--csv|--md]     Export entries to file
    serve [port]            Start local dashboard server (default: 8080)
    open                    Open dashboard in browser

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version
    --severity <level>      Filter by severity (critical, high, medium, low)
    --agent <name>          Specify agent for new entry

EXAMPLES:
    blackboard list
    blackboard add "ECHO SECRETS TO TERMINAL" --severity critical
    blackboard violations --last 24h
    blackboard search "hallucinate"
    blackboard agent bart
    blackboard export --csv > violations.csv
    blackboard serve 3000

HELP
}

# Show version
show_version() {
    echo "SimpleLLMs Blackboard CLI v1.1.0 (P0 Hardened)"
}

# List all entries
cmd_list() {
    local filter_agent="${1:-}"

    echo -e "${BOLD}${CYAN}SimpleLLMs Blackboard${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local count
    count=$(jq '.entries | length' "$BLACKBOARD_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No entries found. The blackboard is clean!${NC}"
        return
    fi

    if [[ -n "$filter_agent" ]]; then
        jq -r --arg agent "$filter_agent" '
            .entries |
            map(select(.agent == $agent or .agent == "universal")) |
            sort_by(.repetitions) | reverse | .[] |
            "\(.severity | if . == "critical" then "🔴" elif . == "high" then "🟠" elif . == "medium" then "🔵" else "🟢" end) \(.violation)\n   Agent: \(.agent) | Reps: \(.repetitions) | ID: \(.id)"
        ' "$BLACKBOARD_FILE"
    else
        jq -r '
            .entries |
            sort_by(.repetitions) | reverse | .[] |
            "\(.severity | if . == "critical" then "🔴" elif . == "high" then "🟠" elif . == "medium" then "🔵" else "🟢" end) \(.violation)\n   Agent: \(.agent) | Reps: \(.repetitions) | ID: \(.id)"
        ' "$BLACKBOARD_FILE"
    fi

    echo ""
}

# Add new entry with locking
cmd_add() {
    local violation="${1:-}"
    local severity="${2:-medium}"
    local agent="${3:-universal}"
    local category="${4:-custom}"

    if [[ -z "$violation" ]]; then
        echo -e "${RED}Error: Violation text required${NC}" >&2
        echo "Usage: blackboard add \"VIOLATION TEXT\"" >&2
        exit 1
    fi

    # Sanitize and normalize (P0 fix: input validation)
    violation=$(sanitize_input "$violation" "$MAX_VIOLATION_LENGTH")
    violation=$(echo "$violation" | tr '[:lower:]' '[:upper:]')

    # Ensure "I WILL NOT" prefix
    if [[ ! "$violation" =~ ^I\ WILL\ NOT ]]; then
        violation="I WILL NOT $violation"
    fi

    # Validate agent
    case "$agent" in
        universal|ralph|bart|lisa|marge|homer) ;;
        *) agent="universal" ;;
    esac

    # Validate severity
    case "$severity" in
        critical|high|medium|low) ;;
        *) severity="medium" ;;
    esac

    # P1 fix: Validate category
    case "$category" in
        hallucination|security|efficiency|scope|quality|custom) ;;
        *) category="custom" ;;
    esac

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id="bb-$(date +%s)-$RANDOM"

    # Acquire lock (P0 fix: concurrent write safety)
    if ! acquire_lock; then
        exit 1
    fi

    # Check for duplicate (case-insensitive)
    local existing
    existing=$(jq -r --arg v "$violation" \
        '.entries[] | select((.violation | ascii_upcase) == ($v | ascii_upcase)) | .id' \
        "$BLACKBOARD_FILE" 2>/dev/null | head -1) || existing=""

    if [[ -n "$existing" ]]; then
        # P0 fix: Use --arg for all variables
        jq --arg id "$existing" --arg ts "$timestamp" \
           '(.entries[] | select(.id == $id)).repetitions += 1 |
            (.entries[] | select(.id == $id)).lastSeen = $ts |
            .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "${BLACKBOARD_FILE}.tmp.$$" && mv "${BLACKBOARD_FILE}.tmp.$$" "$BLACKBOARD_FILE"
        echo -e "${YELLOW}Entry exists. Incremented repetitions.${NC}"
    else
        # P0 fix: Use --arg for ALL user input to prevent JSON injection
        jq --arg id "$id" \
           --arg ts "$timestamp" \
           --arg v "$violation" \
           --arg agent "$agent" \
           --arg sev "$severity" \
           --arg cat "$category" \
           '.entries += [{
               "id": $id,
               "timestamp": $ts,
               "lastSeen": $ts,
               "agent": $agent,
               "violation": $v,
               "context": "Added via CLI",
               "trigger": "cli",
               "repetitions": 1,
               "severity": $sev,
               "category": $cat
           }] |
           .meta.totalEntries = (.entries | length) |
           .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "${BLACKBOARD_FILE}.tmp.$$" && mv "${BLACKBOARD_FILE}.tmp.$$" "$BLACKBOARD_FILE"
        echo -e "${GREEN}Added: $violation${NC}"
    fi

    release_lock
}

# Show statistics
cmd_check() {
    echo -e "${BOLD}${CYAN}Blackboard Statistics${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local total critical high medium low total_reps

    total=$(jq '.entries | length' "$BLACKBOARD_FILE")
    critical=$(jq '[.entries[] | select(.severity == "critical")] | length' "$BLACKBOARD_FILE")
    high=$(jq '[.entries[] | select(.severity == "high")] | length' "$BLACKBOARD_FILE")
    medium=$(jq '[.entries[] | select(.severity == "medium")] | length' "$BLACKBOARD_FILE")
    low=$(jq '[.entries[] | select(.severity == "low")] | length' "$BLACKBOARD_FILE")
    total_reps=$(jq '[.entries[].repetitions] | add // 0' "$BLACKBOARD_FILE")

    echo -e "Total Entries:      ${BOLD}$total${NC}"
    echo -e "Total Repetitions:  ${BOLD}$total_reps${NC}"
    echo ""
    echo -e "${RED}● Critical:${NC}         $critical"
    echo -e "${YELLOW}● High:${NC}             $high"
    echo -e "${BLUE}● Medium:${NC}           $medium"
    echo -e "${GREEN}● Low:${NC}              $low"
    echo ""
    echo -e "${CYAN}By Agent:${NC}"
    jq -r '.entries | group_by(.agent) | .[] | "  \(.[0].agent): \(length)"' "$BLACKBOARD_FILE" 2>/dev/null || echo "  (none)"
}

# Show recent violations
cmd_violations() {
    local hours="${1:-24}"

    # Cross-platform date calculation
    local cutoff_ts
    if date -v-1d &>/dev/null; then
        # macOS
        cutoff_ts=$(date -v-"${hours}"H -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        # GNU/Linux
        cutoff_ts=$(date -d "$hours hours ago" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    echo -e "${BOLD}Violations in last ${hours}h${NC}"
    echo ""

    local count
    count=$(jq --arg cutoff "$cutoff_ts" '
        [.entries | map(select(.timestamp >= $cutoff or .lastSeen >= $cutoff))] | .[0] | length
    ' "$BLACKBOARD_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}No recent violations. Good behavior!${NC}"
        return
    fi

    jq -r --arg cutoff "$cutoff_ts" '
        .entries |
        map(select(.timestamp >= $cutoff or .lastSeen >= $cutoff)) |
        sort_by(.lastSeen) | reverse |
        .[] |
        "[\(.severity)] \(.violation)\n  Last seen: \(.lastSeen)"
    ' "$BLACKBOARD_FILE"
}

# Search entries
cmd_search() {
    local query="${1:-}"

    if [[ -z "$query" ]]; then
        echo -e "${RED}Error: Search query required${NC}" >&2
        exit 1
    fi

    echo -e "${BOLD}Search results for: ${CYAN}$query${NC}"
    echo ""

    # P0 fix: Use --arg for query to prevent injection
    local count
    count=$(jq --arg q "$query" '
        [.entries | map(select(
            (.violation | ascii_downcase | contains($q | ascii_downcase)) or
            (.context | ascii_downcase | contains($q | ascii_downcase))
        ))] | .[0] | length
    ' "$BLACKBOARD_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}No matches found.${NC}"
        return
    fi

    jq -r --arg q "$query" '
        .entries |
        map(select(
            (.violation | ascii_downcase | contains($q | ascii_downcase)) or
            (.context | ascii_downcase | contains($q | ascii_downcase))
        )) |
        .[] |
        "● \(.violation)\n  \(.context | .[0:100])...\n"
    ' "$BLACKBOARD_FILE"
}

# Delete entry with locking
cmd_delete() {
    local id="${1:-}"

    if [[ -z "$id" ]]; then
        echo -e "${RED}Error: Entry ID required${NC}" >&2
        exit 1
    fi

    # P0 fix: Use --arg for id
    local exists
    exists=$(jq -r --arg id "$id" '.entries[] | select(.id == $id) | .violation' "$BLACKBOARD_FILE" 2>/dev/null) || exists=""

    if [[ -z "$exists" ]]; then
        echo -e "${RED}Entry not found: $id${NC}" >&2
        exit 1
    fi

    echo -e "Delete: ${YELLOW}$exists${NC}? [y/N]"
    read -r confirm || confirm="n"

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if ! acquire_lock; then
            exit 1
        fi

        # P0 fix: Use --arg for id
        jq --arg id "$id" \
           'del(.entries[] | select(.id == $id)) | .meta.totalEntries = (.entries | length)' \
           "$BLACKBOARD_FILE" > "${BLACKBOARD_FILE}.tmp.$$" && mv "${BLACKBOARD_FILE}.tmp.$$" "$BLACKBOARD_FILE"

        release_lock
        echo -e "${GREEN}Deleted.${NC}"
    else
        echo -e "${YELLOW}Cancelled.${NC}"
    fi
}

# Export entries
cmd_export() {
    local format="${1:-json}"

    case "$format" in
        --csv|csv)
            echo "id,agent,violation,severity,repetitions,timestamp,lastSeen"
            jq -r '.entries[] | [.id, .agent, .violation, .severity, .repetitions, .timestamp, .lastSeen] | @csv' "$BLACKBOARD_FILE"
            ;;
        --md|md)
            echo "# SimpleLLMs Blackboard Export"
            echo ""
            echo "Exported: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
            echo ""
            echo "| Violation | Agent | Severity | Repetitions |"
            echo "|-----------|-------|----------|-------------|"
            # P1 fix: Escape pipes in markdown to prevent injection
            jq -r '.entries[] | "| \(.violation | gsub("\\|"; "\\|")) | \(.agent) | \(.severity) | \(.repetitions) |"' "$BLACKBOARD_FILE"
            ;;
        *)
            jq '.' "$BLACKBOARD_FILE"
            ;;
    esac
}

# Start dashboard server
cmd_serve() {
    local port="${1:-8080}"

    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}Starting dashboard at http://localhost:$port${NC}"
        echo -e "Press Ctrl+C to stop"
        cd "$BLACKBOARD_DIR"
        python3 -m http.server "$port"
    elif command -v php &> /dev/null; then
        echo -e "${GREEN}Starting dashboard at http://localhost:$port${NC}"
        cd "$BLACKBOARD_DIR"
        php -S localhost:"$port"
    else
        echo -e "${RED}No server available. Install Python 3.${NC}" >&2
        exit 1
    fi
}

# Open dashboard in browser
cmd_open() {
    if [[ -f "$DASHBOARD_FILE" ]]; then
        if command -v open &> /dev/null; then
            open "$DASHBOARD_FILE"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$DASHBOARD_FILE"
        else
            echo "Open: file://$DASHBOARD_FILE"
        fi
    else
        echo -e "${RED}Dashboard not found: $DASHBOARD_FILE${NC}" >&2
        exit 1
    fi
}

# Main
main() {
    check_deps
    init_blackboard

    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        list|ls)
            cmd_list "$@"
            ;;
        add)
            # Parse options
            local violation="" severity="medium" agent="universal"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --severity)
                        severity="${2:-medium}"
                        shift 2
                        ;;
                    --agent)
                        agent="${2:-universal}"
                        shift 2
                        ;;
                    *)
                        violation="$1"
                        shift
                        ;;
                esac
            done
            cmd_add "$violation" "$severity" "$agent"
            ;;
        check|stats)
            cmd_check
            ;;
        violations)
            local hours="24"
            if [[ "${1:-}" == "--last" ]]; then
                hours="${2:-24}"
                hours="${hours%h}"  # Remove trailing 'h' if present
            fi
            cmd_violations "$hours"
            ;;
        search|find)
            cmd_search "$@"
            ;;
        agent)
            cmd_list "$1"
            ;;
        delete|rm)
            cmd_delete "$@"
            ;;
        export)
            cmd_export "$@"
            ;;
        serve|server)
            cmd_serve "$@"
            ;;
        open)
            cmd_open
            ;;
        -h|--help|help)
            show_help
            ;;
        -v|--version)
            show_version
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
