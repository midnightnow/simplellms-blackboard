# Blackboard Skill

> Capture agent corrections and learned limitations

## Activation Triggers

This skill activates when the agent says phrases like:
- "never do"
- "I told you not to"
- "don't do that"
- "should not"
- "must not"
- "stop doing"
- "that's wrong"
- "incorrect approach"

## Behavior

When a correction is detected:

1. **Detect**: Parse the correction from the agent's response
2. **Format**: Convert to "I WILL NOT [action]" format
3. **Prompt**: Ask user if they want to save to blackboard
4. **Save**: Append to `blackboard.json` if confirmed

## Example Flow

```
Agent: "I told you not to echo secrets to the terminal!"

[Blackboard Skill Activates]

Would you like to add this to the blackboard?

  I WILL NOT ECHO SECRETS TO TERMINAL

Options:
  [Save to Blackboard] [Dismiss] [Edit First]
```

## Integration

### Hook Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "post_response": {
      "command": "~/.claude/skills/blackboard/capture.sh",
      "triggers": ["never do", "I told you", "must not", "should not"]
    }
  }
}
```

### Capture Script

```bash
#!/bin/bash
# capture.sh - Blackboard capture hook

RESPONSE="$1"
BLACKBOARD_FILE="$HOME/Projects/simplellms-blackboard/blackboard.json"

# Check for trigger phrases
if echo "$RESPONSE" | grep -qiE "(never do|I told you|must not|should not|don't do)"; then
    # Extract the violation
    VIOLATION=$(echo "$RESPONSE" | grep -oiE "(never|don't|must not|should not) [^.!?]+" | head -1)

    if [ -n "$VIOLATION" ]; then
        # Normalize to "I WILL NOT" format
        NORMALIZED=$(echo "$VIOLATION" | sed 's/never /I WILL NOT /i' | tr '[:lower:]' '[:upper:]')

        echo "Blackboard: Detected correction - $NORMALIZED"
        echo "Add to blackboard? (y/n)"
    fi
fi
```

## Dashboard Access

Open the visual dashboard:

```bash
open ~/Projects/simplellms-blackboard/dashboard.html
```

Or serve locally:

```bash
cd ~/Projects/simplellms-blackboard
python -m http.server 8080
# Visit http://localhost:8080/dashboard.html
```

## Manual Entry

Add entries directly:

```bash
# Via command line
simplellms blackboard add "HALLUCINATE FILE PATHS" --agent universal --severity critical

# Via dashboard
open dashboard.html → Click "+ Add Entry"
```

## Categories

| Category | Description | Color |
|----------|-------------|-------|
| `hallucination` | Making up information | Red |
| `security` | Credential/security violations | Dark Red |
| `efficiency` | Wasted tokens/time | Orange |
| `scope` | Going beyond the task | Blue |
| `quality` | Code quality issues | Purple |

## Severity Levels

| Level | When to Use |
|-------|-------------|
| `critical` | Security risks, data loss potential |
| `high` | Significant waste or breakage |
| `medium` | Inefficiency, scope issues |
| `low` | Minor corrections |

## Related Files

- `blackboard.json` - Data store
- `dashboard.html` - Visual interface
- `agents/*.md` - Per-agent blackboard rules
- `README.md` - Full documentation

## Philosophy

> "The first step to not making mistakes is knowing what mistakes look like."

The Blackboard is inspired by The Simpsons' detention gag where Bart writes his violations repeatedly. For AI agents, this serves as:

1. **Visible Learning** - Document what went wrong
2. **Pattern Recognition** - Identify recurring issues
3. **Training Data** - Potential future fine-tuning source
4. **Team Knowledge** - Share lessons across sessions

---

*Part of SimpleLLMs - Simple LLM Suite*
