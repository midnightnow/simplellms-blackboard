#!/bin/bash
# SimpleLLMs Blackboard Capture Hook - v1.1.0 (P0 Hardened)
# Detects agent corrections and persists them to blackboard.json
#
# Security Fixes (Red Zen P0):
# - File locking for concurrent write safety
# - Input size limits to prevent DoS
# - JSON injection protection via jq --arg
# - Input sanitization
#
# Usage: ./capture.sh "Agent response text" OR echo "text" | ./capture.sh
# Requires: jq (brew install jq)

set -euo pipefail

# Configuration
BLACKBOARD_DIR="${BLACKBOARD_DIR:-$HOME/Projects/simplellms-blackboard}"
BLACKBOARD_FILE="$BLACKBOARD_DIR/blackboard.json"
LOCK_DIR="$BLACKBOARD_DIR/.blackboard.lock"
LOG_FILE="$BLACKBOARD_DIR/capture.log"
MAX_STDIN_SIZE=10240      # 10KB limit on input
MAX_VIOLATION_LENGTH=200  # Max chars for violation text
MAX_CONTEXT_LENGTH=500    # Max chars for context
LOCK_TIMEOUT=10           # Seconds to wait for lock

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging with secure file permissions
log() {
    local level="$1"; shift
    # P1 fix: Ensure log file has secure permissions
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE" 2>/dev/null && chmod 600 "$LOG_FILE" 2>/dev/null || true
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Portable file locking using mkdir (atomic on all filesystems)
acquire_lock() {
    local attempts=0
    local max_attempts=$((LOCK_TIMEOUT * 10))

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            echo -e "${RED}Error: Could not acquire lock after ${LOCK_TIMEOUT}s${NC}" >&2
            log "ERROR" "Lock acquisition timeout"
            return 1
        fi
        sleep 0.1
    done

    # Store PID for stale lock detection
    echo $$ > "$LOCK_DIR/pid"
    # P1 fix: Handle SIGINT/SIGTERM for lock cleanup
    trap release_lock EXIT INT TERM
    return 0
}

release_lock() {
    rm -rf "$LOCK_DIR" 2>/dev/null || true
}

# Check for stale lock (process died without releasing)
check_stale_lock() {
    if [[ -d "$LOCK_DIR" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
        if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
            log "WARN" "Removing stale lock from PID $lock_pid"
            rm -rf "$LOCK_DIR"
        fi
    fi
}

# Sanitize input - remove dangerous characters, enforce length
sanitize_input() {
    local input="$1"
    local max_len="${2:-$MAX_VIOLATION_LENGTH}"

    # Remove control characters, null bytes
    # Escape quotes and backslashes for JSON safety
    echo "$input" | \
        tr -d '\000-\011\013-\037' | \
        sed 's/\\/\\\\/g; s/"/\\"/g' | \
        head -c "$max_len"
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}" >&2
        echo "Install with: brew install jq" >&2
        exit 1
    fi
}

# Initialize blackboard.json if it doesn't exist
init_blackboard() {
    if [[ ! -f "$BLACKBOARD_FILE" ]]; then
        log "INFO" "Creating new blackboard.json"
        cat > "$BLACKBOARD_FILE" << 'INIT_JSON'
{
  "version": "1.0.0",
  "meta": {
    "title": "SimpleLLMs Blackboard",
    "description": "Agent corrections and learned limitations",
    "lastUpdated": "",
    "totalEntries": 0
  },
  "entries": []
}
INIT_JSON
        chmod 600 "$BLACKBOARD_FILE"  # Owner-only permissions
    fi
}

# Add entry with file locking (P0 fix: concurrent write safety)
add_entry() {
    local violation="$1"
    local context="$2"
    local agent="${3:-universal}"
    local severity="${4:-medium}"
    local category="${5:-custom}"

    # Sanitize all inputs (P0 fix: injection protection)
    violation=$(sanitize_input "$violation" "$MAX_VIOLATION_LENGTH")
    context=$(sanitize_input "$context" "$MAX_CONTEXT_LENGTH")
    agent=$(echo "$agent" | tr -cd 'a-z')  # Only lowercase letters

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

    # Acquire lock before any file operations
    check_stale_lock
    if ! acquire_lock; then
        return 1
    fi

    # Check for duplicate (case-insensitive)
    local violation_upper=$(echo "$violation" | tr '[:lower:]' '[:upper:]')
    local existing
    existing=$(jq -r --arg v "$violation_upper" \
        '.entries[] | select((.violation | ascii_upcase) == $v) | .id' \
        "$BLACKBOARD_FILE" 2>/dev/null | head -1) || existing=""

    if [[ -n "$existing" ]]; then
        # Increment repetitions for existing entry
        # P1 fix: Use PID in temp file name to prevent symlink attacks
        if jq --arg id "$existing" \
           --arg ts "$timestamp" \
           '(.entries[] | select(.id == $id)).repetitions += 1 |
            (.entries[] | select(.id == $id)).lastSeen = $ts |
            .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "${BLACKBOARD_FILE}.tmp.$$"; then
            mv "${BLACKBOARD_FILE}.tmp.$$" "$BLACKBOARD_FILE"
            log "INFO" "Incremented repetitions for: $existing"
            echo -e "${YELLOW}Entry exists. Incremented repetition count.${NC}"
        else
            rm -f "${BLACKBOARD_FILE}.tmp.$$"
            log "ERROR" "Failed to update existing entry"
            return 1
        fi
    else
        # Add new entry using --arg for all user input (P0 fix: JSON injection)
        if jq --arg id "$id" \
           --arg ts "$timestamp" \
           --arg violation "$violation" \
           --arg context "$context" \
           --arg agent "$agent" \
           --arg severity "$severity" \
           --arg category "$category" \
           '.entries += [{
               "id": $id,
               "timestamp": $ts,
               "lastSeen": $ts,
               "agent": $agent,
               "violation": $violation,
               "context": $context,
               "trigger": "capture.sh",
               "repetitions": 1,
               "severity": $severity,
               "category": $category
           }] |
           .meta.totalEntries = (.entries | length) |
           .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "${BLACKBOARD_FILE}.tmp.$$"; then
            mv "${BLACKBOARD_FILE}.tmp.$$" "$BLACKBOARD_FILE"
            log "INFO" "Added new entry: $id - $violation"
            echo -e "${GREEN}Added to blackboard: $violation${NC}"
        else
            rm -f "${BLACKBOARD_FILE}.tmp.$$"
            log "ERROR" "Failed to add new entry"
            return 1
        fi
    fi

    # Lock released automatically via trap
    return 0
}

# Detect trigger phrases
detect_correction() {
    local text="$1"
    local triggers=(
        "never do" "I told you" "must not" "should not"
        "don't do that" "stop doing" "that's wrong"
        "WILL NOT" "shouldn't" "mustn't" "do not" "incorrect"
    )

    for trigger in "${triggers[@]}"; do
        if echo "$text" | grep -qi "$trigger"; then
            return 0
        fi
    done
    return 1
}

# Extract violation from text
extract_violation() {
    local text="$1"
    local violation=""

    # Pattern: "never do X" or "don't do X"
    violation=$(echo "$text" | grep -oiE "(never|don't|do not|must not|should not|stop)[[:space:]]+[^.!?\n]{5,80}" | head -1) || true

    if [[ -n "$violation" ]]; then
        violation=$(echo "$violation" | sed -E "s/(never|don't|do not|must not|should not|stop)[[:space:]]+//" | tr '[:lower:]' '[:upper:]')
        echo "I WILL NOT $violation"
        return 0
    fi

    # Pattern: "I told you not to X"
    violation=$(echo "$text" | grep -oiE "I told you (not to|never to)[[:space:]]+[^.!?\n]{5,80}" | head -1) || true

    if [[ -n "$violation" ]]; then
        violation=$(echo "$violation" | sed -E "s/I told you (not to|never to)[[:space:]]+//" | tr '[:lower:]' '[:upper:]')
        echo "I WILL NOT $violation"
        return 0
    fi

    return 1
}

# Interactive prompt
prompt_add_entry() {
    local violation="$1"
    local context="$2"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}BLACKBOARD CAPTURE DETECTED${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    printf "${BLUE}║${NC}  %-60s ${BLUE}║${NC}\n" "${violation:0:60}"
    echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Add to blackboard? [${GREEN}Y${NC}/n/e(dit)/s(everity)/a(gent)]"

    read -r CHOICE || CHOICE="n"

    local severity="medium"
    local agent="universal"

    case "$CHOICE" in
        [Yy]|"")
            add_entry "$violation" "$context" "$agent" "$severity"
            ;;
        [Ee])
            echo "Enter corrected violation (without 'I WILL NOT'):"
            read -r edited || edited=""
            if [[ -n "$edited" ]]; then
                edited=$(echo "$edited" | tr '[:lower:]' '[:upper:]' | head -c "$MAX_VIOLATION_LENGTH")
                violation="I WILL NOT $edited"
                add_entry "$violation" "$context" "$agent" "$severity"
            else
                echo -e "${RED}No input provided. Skipped.${NC}"
            fi
            ;;
        [Ss])
            echo "Select severity: [c]ritical, [h]igh, [m]edium, [l]ow"
            read -r sev_choice || sev_choice="m"
            case "$sev_choice" in
                [Cc]) severity="critical" ;;
                [Hh]) severity="high" ;;
                [Ll]) severity="low" ;;
                *) severity="medium" ;;
            esac
            add_entry "$violation" "$context" "$agent" "$severity"
            ;;
        [Aa])
            echo "Select agent: [u]niversal, [r]alph, [b]art, [l]isa, [m]arge, [h]omer"
            read -r agent_choice || agent_choice="u"
            case "$agent_choice" in
                [Rr]) agent="ralph" ;;
                [Bb]) agent="bart" ;;
                [Ll]) agent="lisa" ;;
                [Mm]) agent="marge" ;;
                [Hh]) agent="homer" ;;
                *) agent="universal" ;;
            esac
            add_entry "$violation" "$context" "$agent" "$severity"
            ;;
        [Nn])
            echo -e "${YELLOW}Skipped.${NC}"
            log "INFO" "User skipped: $violation"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Skipped.${NC}"
            ;;
    esac
}

# Main
main() {
    check_dependencies
    init_blackboard

    local response=""

    if [[ $# -gt 0 ]]; then
        response="$1"
    else
        # P0 fix: Limit stdin to prevent DoS/OOM
        response=$(head -c "$MAX_STDIN_SIZE")

        # Warn if input was truncated
        if [[ ${#response} -ge $MAX_STDIN_SIZE ]]; then
            log "WARN" "Input truncated to $MAX_STDIN_SIZE bytes"
            echo -e "${YELLOW}Warning: Input truncated to ${MAX_STDIN_SIZE} bytes${NC}" >&2
        fi
    fi

    if [[ -z "$response" ]]; then
        echo -e "${RED}Usage: $0 \"response text\" or echo \"text\" | $0${NC}" >&2
        exit 1
    fi

    if detect_correction "$response"; then
        local violation
        if violation=$(extract_violation "$response"); then
            local context="${response:0:$MAX_CONTEXT_LENGTH}"
            prompt_add_entry "$violation" "$context"
        else
            log "WARN" "Trigger detected but couldn't extract violation"
        fi
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
