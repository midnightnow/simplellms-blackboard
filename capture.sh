#!/bin/bash
# SimpleLLMs Blackboard Capture Hook
# Detects agent corrections and persists them to blackboard.json
#
# Usage: ./capture.sh "Agent response text containing correction"
# Requires: jq (brew install jq)

set -euo pipefail

# Configuration
BLACKBOARD_DIR="${BLACKBOARD_DIR:-$HOME/Projects/simplellms-blackboard}"
BLACKBOARD_FILE="$BLACKBOARD_DIR/blackboard.json"
MAX_VIOLATION_LENGTH=200
LOG_FILE="$BLACKBOARD_DIR/capture.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
}

# Sanitize input - remove special characters that could break JSON
sanitize_input() {
    local input="$1"
    # Remove control characters, escape quotes and backslashes
    echo "$input" | tr -d '\000-\031' | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c "$MAX_VIOLATION_LENGTH"
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo "Install with: brew install jq"
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
    fi
}

# Add entry to blackboard.json using jq
add_entry() {
    local violation="$1"
    local context="$2"
    local agent="${3:-universal}"
    local severity="${4:-medium}"
    local category="${5:-custom}"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id="bb-$(date +%s)-$RANDOM"

    # Sanitize inputs
    violation=$(sanitize_input "$violation")
    context=$(sanitize_input "$context")

    # Check for duplicate
    local existing=$(jq -r --arg v "$violation" '.entries[] | select(.violation == $v) | .id' "$BLACKBOARD_FILE" 2>/dev/null | head -1)

    if [[ -n "$existing" ]]; then
        # Increment repetitions for existing entry
        jq --arg id "$existing" \
           --arg ts "$timestamp" \
           '(.entries[] | select(.id == $id)).repetitions += 1 |
            (.entries[] | select(.id == $id)).lastSeen = $ts |
            .meta.lastUpdated = $ts' \
           "$BLACKBOARD_FILE" > "$BLACKBOARD_FILE.tmp" && mv "$BLACKBOARD_FILE.tmp" "$BLACKBOARD_FILE"

        log "INFO" "Incremented repetitions for existing entry: $existing"
        echo -e "${YELLOW}Entry already exists. Incremented repetition count.${NC}"
        return 0
    fi

    # Add new entry
    jq --arg id "$id" \
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
       "$BLACKBOARD_FILE" > "$BLACKBOARD_FILE.tmp" && mv "$BLACKBOARD_FILE.tmp" "$BLACKBOARD_FILE"

    log "INFO" "Added new entry: $id - $violation"
    echo -e "${GREEN}Added to blackboard: $violation${NC}"
    return 0
}

# Detect trigger phrases in text
detect_correction() {
    local text="$1"

    # Trigger phrases that indicate a correction
    local triggers=(
        "never do"
        "I told you"
        "must not"
        "should not"
        "don't do that"
        "stop doing"
        "that's wrong"
        "WILL NOT"
        "shouldn't"
        "mustn't"
        "do not"
        "incorrect"
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

    # Try to extract the action after trigger phrases
    local violation=""

    # Pattern: "never do X" or "don't do X"
    violation=$(echo "$text" | grep -oiE "(never|don't|do not|must not|should not|stop) [^.!?\n]{5,80}" | head -1)

    if [[ -n "$violation" ]]; then
        # Normalize to uppercase "I WILL NOT X" format
        violation=$(echo "$violation" | sed -E "s/(never|don't|do not|must not|should not|stop) //" | tr '[:lower:]' '[:upper:]')
        echo "I WILL NOT $violation"
        return 0
    fi

    # Pattern: "I told you not to X"
    violation=$(echo "$text" | grep -oiE "I told you (not to|never to) [^.!?\n]{5,80}" | head -1)

    if [[ -n "$violation" ]]; then
        violation=$(echo "$violation" | sed -E "s/I told you (not to|never to) //" | tr '[:lower:]' '[:upper:]')
        echo "I WILL NOT $violation"
        return 0
    fi

    return 1
}

# Interactive prompt for adding entry
prompt_add_entry() {
    local violation="$1"
    local context="$2"

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${YELLOW}BLACKBOARD CAPTURE DETECTED${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    printf "${BLUE}║${NC}  %-60s ${BLUE}║${NC}\n" "$violation"
    echo -e "${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Add this to the blackboard? [${GREEN}Y${NC}/n/e(dit)/s(everity)/a(gent)]"

    read -r CHOICE

    local severity="medium"
    local agent="universal"

    case "$CHOICE" in
        [Yy]|"")
            add_entry "$violation" "$context" "$agent" "$severity"
            ;;
        [Ee])
            echo -e "Enter corrected violation (without 'I WILL NOT'):"
            read -r edited
            if [[ -n "$edited" ]]; then
                edited=$(echo "$edited" | tr '[:lower:]' '[:upper:]' | head -c "$MAX_VIOLATION_LENGTH")
                violation="I WILL NOT $edited"
                add_entry "$violation" "$context" "$agent" "$severity"
            else
                echo -e "${RED}No input provided. Skipped.${NC}"
            fi
            ;;
        [Ss])
            echo -e "Select severity: [c]ritical, [h]igh, [m]edium, [l]ow"
            read -r sev_choice
            case "$sev_choice" in
                [Cc]) severity="critical" ;;
                [Hh]) severity="high" ;;
                [Ll]) severity="low" ;;
                *) severity="medium" ;;
            esac
            add_entry "$violation" "$context" "$agent" "$severity"
            ;;
        [Aa])
            echo -e "Select agent: [u]niversal, [r]alph, [b]art, [l]isa, [m]arge, [h]omer"
            read -r agent_choice
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
            log "INFO" "User skipped adding: $violation"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Skipped.${NC}"
            ;;
    esac
}

# Main function
main() {
    check_dependencies
    init_blackboard

    # Get response text from argument or stdin
    local response=""
    if [[ $# -gt 0 ]]; then
        response="$1"
    else
        # Read from stdin if no argument
        response=$(cat)
    fi

    if [[ -z "$response" ]]; then
        echo -e "${RED}Usage: $0 \"response text\" or echo \"text\" | $0${NC}"
        exit 1
    fi

    # Check for trigger phrases
    if detect_correction "$response"; then
        # Extract the violation
        local violation
        if violation=$(extract_violation "$response"); then
            # Get context (truncate to reasonable length)
            local context=$(echo "$response" | head -c 500)
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
