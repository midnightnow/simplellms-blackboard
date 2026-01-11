#!/bin/bash
# SimpleLLMs Blackboard CLI
# Command-line interface for managing blackboard entries
#
# Usage:
#   blackboard list                    - List all entries
#   blackboard add "VIOLATION"         - Add new entry
#   blackboard check                   - Show stats
#   blackboard violations [--last 24h] - Show recent violations
#   blackboard search "query"          - Search entries
#   blackboard export                  - Export to CSV
#   blackboard serve                   - Start dashboard server

set -euo pipefail

# Configuration
BLACKBOARD_DIR="${BLACKBOARD_DIR:-$HOME/Projects/simplellms-blackboard}"
BLACKBOARD_FILE="$BLACKBOARD_DIR/blackboard.json"
DASHBOARD_FILE="$BLACKBOARD_DIR/dashboard.html"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check dependencies
check_deps() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required. Install with: brew install jq${NC}"
        exit 1
    fi
}

# Initialize blackboard if needed
init_blackboard() {
    if [[ ! -f "$BLACKBOARD_FILE" ]]; then
        echo '{"version":"1.0.0","meta":{"title":"SimpleLLMs Blackboard","totalEntries":0},"entries":[]}' > "$BLACKBOARD_FILE"
    fi
}

# Show help
show_help() {
    cat << 'HELP'
SimpleLLMs Blackboard CLI

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
    local version=$(jq -r '.version // "1.0.0"' "$BLACKBOARD_FILE")
    echo "SimpleLLMs Blackboard CLI v$version"
}

# List all entries
cmd_list() {
    local filter_agent="${1:-}"

    echo -e "${BOLD}${CYAN}SimpleLLMs Blackboard${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local entries
    if [[ -n "$filter_agent" ]]; then
        entries=$(jq -r --arg agent "$filter_agent" '.entries[] | select(.agent == $agent or .agent == "universal")' "$BLACKBOARD_FILE")
    else
        entries=$(jq -r '.entries[]' "$BLACKBOARD_FILE")
    fi

    if [[ -z "$entries" ]]; then
        echo -e "${YELLOW}No entries found.${NC}"
        return
    fi

    jq -r '.entries | sort_by(.repetitions) | reverse | .[] |
        "\(.severity | if . == "critical" then "\u001b[31m●\u001b[0m" elif . == "high" then "\u001b[33m●\u001b[0m" elif . == "medium" then "\u001b[34m●\u001b[0m" else "\u001b[32m●\u001b[0m" end) \u001b[1m\(.violation)\u001b[0m\n  Agent: \(.agent) | Repetitions: \(.repetitions) | \(.id)"' "$BLACKBOARD_FILE"

    echo ""
}

# Add new entry
cmd_add() {
    local violation="$1"
    local severity="${2:-medium}"
    local agent="${3:-universal}"
    local category="${4:-custom}"

    # Normalize violation
    violation=$(echo "$violation" | tr '[:lower:]' '[:upper:]')
    if [[ ! "$violation" =~ ^I\ WILL\ NOT ]]; then
        violation="I WILL NOT $violation"
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id="bb-$(date +%s)-$RANDOM"

    # Check for duplicate
    local existing=$(jq -r --arg v "$violation" '.entries[] | select(.violation == $v) | .id' "$BLACKBOARD_FILE" | head -1)

    if [[ -n "$existing" ]]; then
        jq --arg id "$existing" --arg ts "$timestamp" \
           '(.entries[] | select(.id == $id)).repetitions += 1 |
            (.entries[] | select(.id == $id)).lastSeen = $ts |
            .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "$BLACKBOARD_FILE.tmp" && mv "$BLACKBOARD_FILE.tmp" "$BLACKBOARD_FILE"
        echo -e "${YELLOW}Entry exists. Incremented repetitions.${NC}"
    else
        jq --arg id "$id" --arg ts "$timestamp" --arg v "$violation" \
           --arg agent "$agent" --arg sev "$severity" --arg cat "$category" \
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
           "$BLACKBOARD_FILE" > "$BLACKBOARD_FILE.tmp" && mv "$BLACKBOARD_FILE.tmp" "$BLACKBOARD_FILE"
        echo -e "${GREEN}Added: $violation${NC}"
    fi
}

# Show statistics
cmd_check() {
    echo -e "${BOLD}${CYAN}Blackboard Statistics${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local total=$(jq '.entries | length' "$BLACKBOARD_FILE")
    local critical=$(jq '[.entries[] | select(.severity == "critical")] | length' "$BLACKBOARD_FILE")
    local high=$(jq '[.entries[] | select(.severity == "high")] | length' "$BLACKBOARD_FILE")
    local medium=$(jq '[.entries[] | select(.severity == "medium")] | length' "$BLACKBOARD_FILE")
    local low=$(jq '[.entries[] | select(.severity == "low")] | length' "$BLACKBOARD_FILE")
    local total_reps=$(jq '[.entries[].repetitions] | add // 0' "$BLACKBOARD_FILE")

    echo -e "Total Entries:      ${BOLD}$total${NC}"
    echo -e "Total Repetitions:  ${BOLD}$total_reps${NC}"
    echo ""
    echo -e "${RED}● Critical:${NC}         $critical"
    echo -e "${YELLOW}● High:${NC}             $high"
    echo -e "${BLUE}● Medium:${NC}           $medium"
    echo -e "${GREEN}● Low:${NC}              $low"
    echo ""
    echo -e "${CYAN}By Agent:${NC}"
    jq -r '.entries | group_by(.agent) | .[] | "  \(.[0].agent): \(length)"' "$BLACKBOARD_FILE"
}

# Show recent violations
cmd_violations() {
    local hours="${1:-24}"
    local cutoff_ts=$(date -v-"${hours}"H -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -d "$hours hours ago" -u +"%Y-%m-%dT%H:%M:%SZ")

    echo -e "${BOLD}Violations in last ${hours}h${NC}"
    echo ""

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
    local query="$1"

    echo -e "${BOLD}Search results for: ${CYAN}$query${NC}"
    echo ""

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

# Delete entry
cmd_delete() {
    local id="$1"

    local exists=$(jq -r --arg id "$id" '.entries[] | select(.id == $id) | .violation' "$BLACKBOARD_FILE")

    if [[ -z "$exists" ]]; then
        echo -e "${RED}Entry not found: $id${NC}"
        exit 1
    fi

    echo -e "Delete: ${YELLOW}$exists${NC}? [y/N]"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        jq --arg id "$id" 'del(.entries[] | select(.id == $id)) | .meta.totalEntries = (.entries | length)' \
           "$BLACKBOARD_FILE" > "$BLACKBOARD_FILE.tmp" && mv "$BLACKBOARD_FILE.tmp" "$BLACKBOARD_FILE"
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
            echo "id,agent,violation,severity,repetitions,timestamp"
            jq -r '.entries[] | [.id, .agent, .violation, .severity, .repetitions, .timestamp] | @csv' "$BLACKBOARD_FILE"
            ;;
        --md|md)
            echo "# SimpleLLMs Blackboard Export"
            echo ""
            echo "| Violation | Agent | Severity | Repetitions |"
            echo "|-----------|-------|----------|-------------|"
            jq -r '.entries[] | "| \(.violation) | \(.agent) | \(.severity) | \(.repetitions) |"' "$BLACKBOARD_FILE"
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
        echo -e "${RED}No server available. Install Python 3.${NC}"
        exit 1
    fi
}

# Open dashboard in browser
cmd_open() {
    if [[ -f "$DASHBOARD_FILE" ]]; then
        open "$DASHBOARD_FILE" 2>/dev/null || xdg-open "$DASHBOARD_FILE" 2>/dev/null || echo "Open: file://$DASHBOARD_FILE"
    else
        echo -e "${RED}Dashboard not found: $DASHBOARD_FILE${NC}"
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
        list|ls)        cmd_list "$@" ;;
        add)            cmd_add "$@" ;;
        check|stats)    cmd_check ;;
        violations)     cmd_violations "${1:-24}" ;;
        search|find)    cmd_search "$@" ;;
        agent)          cmd_list "$1" ;;
        delete|rm)      cmd_delete "$@" ;;
        export)         cmd_export "$@" ;;
        serve|server)   cmd_serve "$@" ;;
        open)           cmd_open ;;
        -h|--help|help) show_help ;;
        -v|--version)   show_version ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
