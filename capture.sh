#!/bin/bash
# SimpleLLMs Blackboard Capture Hook
# Detects agent corrections and offers to save them

set -e

BLACKBOARD_DIR="$HOME/Projects/simplellms-blackboard"
BLACKBOARD_FILE="$BLACKBOARD_DIR/blackboard.json"
RESPONSE="$1"

# Trigger phrases that indicate a correction
TRIGGERS="never do|I told you|must not|should not|don't do that|stop doing|that's wrong|WILL NOT"

# Check if response contains trigger phrases
if echo "$RESPONSE" | grep -qiE "$TRIGGERS"; then

    # Extract the violation context
    CONTEXT=$(echo "$RESPONSE" | grep -oiE ".{0,50}(never|don't|must not|should not|stop) [^.!?]+.{0,20}" | head -1)

    if [ -n "$CONTEXT" ]; then
        # Try to extract the specific action
        ACTION=$(echo "$CONTEXT" | sed -E 's/.*(never|don'"'"'t|must not|should not|stop) //i' | sed 's/[.!?].*//' | tr '[:lower:]' '[:upper:]')

        if [ -n "$ACTION" ]; then
            # Format as blackboard entry
            VIOLATION="I WILL NOT $ACTION"

            echo ""
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  BLACKBOARD CAPTURE DETECTED                                 ║"
            echo "╠══════════════════════════════════════════════════════════════╣"
            echo "║                                                              ║"
            printf "║  %-60s ║\n" "$VIOLATION"
            echo "║                                                              ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "Add this to the blackboard? [Y/n/e(dit)]"

            read -r CHOICE

            case "$CHOICE" in
                [Yy]|"")
                    # Add to blackboard.json
                    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                    ID="bb-$(date +%s)"

                    # Create new entry (simplified - real impl would use jq)
                    echo "Added to blackboard: $VIOLATION"
                    echo "View at: file://$BLACKBOARD_DIR/dashboard.html"
                    ;;
                [Ee])
                    echo "Enter corrected violation (without 'I WILL NOT'):"
                    read -r EDITED
                    VIOLATION="I WILL NOT $(echo "$EDITED" | tr '[:lower:]' '[:upper:]')"
                    echo "Added to blackboard: $VIOLATION"
                    ;;
                *)
                    echo "Skipped."
                    ;;
            esac
        fi
    fi
fi
