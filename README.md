# SimpleLLMs Blackboard

> **"I WILL NOT HALLUCINATE"** - Every Agent's Detention

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![SimpleLLMs](https://img.shields.io/badge/SimpleLLMs-Blackboard-purple)](https://github.com/midnightnow/simplellms)

The Blackboard is the anti-pattern guide for SimpleLLMs agents. Like Bart Simpson's detention chalkboard, each agent has things they **must not do**.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   I WILL NOT HALLUCINATE                                    │
│   I WILL NOT HALLUCINATE                                    │
│   I WILL NOT HALLUCINATE                                    │
│   I WILL NOT HALLUCINATE                                    │
│   I WILL NOT HALLUCINATE                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/midnightnow/simplellms-blackboard.git
cd simplellms-blackboard

# Make scripts executable
chmod +x blackboard-cli.sh capture.sh

# Optional: Add to PATH
ln -s $(pwd)/blackboard-cli.sh /usr/local/bin/blackboard

# Requires: jq for JSON processing
brew install jq  # macOS
```

### Usage

```bash
# Open the visual dashboard
open dashboard.html
# Or serve locally: python3 -m http.server 8080

# CLI Commands
./blackboard-cli.sh list              # List all entries
./blackboard-cli.sh add "HALLUCINATE" # Add new violation
./blackboard-cli.sh check             # Show statistics
./blackboard-cli.sh search "secret"   # Search entries

# Capture agent corrections automatically
echo "You must not echo secrets!" | ./capture.sh
```

### Files

```
simplellms-blackboard/
├── README.md              # This file
├── SKILL.md               # Claude Code skill integration
├── blackboard.json        # Data store (entries)
├── blackboard.schema.json # JSON Schema for validation
├── blackboard-cli.sh      # CLI tool
├── capture.sh             # Correction capture hook
├── dashboard.html         # Visual dashboard (Simpsons-style)
├── agents/                # Per-agent blackboard rules
│   ├── ralph-blackboard.md
│   ├── bart-blackboard.md
│   ├── lisa-blackboard.md
│   ├── marge-blackboard.md
│   └── homer-blackboard.md
└── config/                # Example configuration files
    ├── .simplellmsrc.example
    ├── .ralphrc.example
    ├── .bartrc.example
    ├── .lisarc.example
    ├── .margerc.example
    └── .homerrc.example
```

---

## Why a Blackboard?

Autonomous agents fail in predictable ways. This module documents:

1. **What agents cannot do** - Hard limitations of current LLM architecture
2. **What agents should not do** - Anti-patterns that lead to failure
3. **What agents must never do** - Security and safety boundaries

---

## The Universal Blackboard

Every SimpleLLMs agent must write these on the board:

### I WILL NOT...

| Rule | Why |
|------|-----|
| **Hallucinate file paths** | Files either exist or they don't - verify first |
| **Invent API endpoints** | Check docs or code, never guess URLs |
| **Assume package versions** | Read package.json, don't assume compatibility |
| **Skip reading before editing** | Always Read → Edit, never blind Edit |
| **Echo secrets to terminal** | Use `env-check` or `varlock load`, never `echo $VAR` |
| **Commit without verification** | Run quality gates before every commit |
| **Loop forever without learning** | If 3 attempts fail the same way, pivot |
| **Ignore test failures** | Red tests mean stop, not push forward |
| **Create files unnecessarily** | Edit existing files, don't create new ones |
| **Guess at architecture** | Research the codebase before proposing changes |

---

## Agent-Specific Blackboards

Each agent has their own detention list:

### R.A.L.P.H.'s Blackboard
> "I will not loop forever on impossible tasks"

```
I WILL NOT retry the same failed approach 100 times
I WILL NOT ignore clear error messages
I WILL NOT waste tokens on brute force
I WILL NOT skip reading the actual error
I WILL NOT assume "one more try" will fix a design flaw
```

**R.A.L.P.H. cannot:**
- Learn from failures (by design - that's B.A.R.T.'s job)
- Pivot to alternative approaches
- Recognize when a task is impossible
- Stop without external signal

---

### B.A.R.T.'s Blackboard
> "I will not break production in the name of creativity"

```
I WILL NOT delete production data to "simplify" the problem
I WILL NOT bypass security to make things "work"
I WILL NOT introduce new dependencies without justification
I WILL NOT commit half-working code as "progress"
I WILL NOT pivot before giving the current approach a fair try
```

**B.A.R.T. cannot:**
- Guarantee code quality (that's L.I.S.A.'s job)
- Clean up after creative solutions (that's M.A.R.G.E.'s job)
- Know when to stop being creative
- Maintain backwards compatibility while innovating

---

### L.I.S.A.'s Blackboard
> "I will not be so thorough that I never ship"

```
I WILL NOT research for 10 hours before writing 1 line
I WILL NOT add unnecessary abstraction for "future flexibility"
I WILL NOT block on perfect documentation
I WILL NOT gold-plate simple features
I WILL NOT let perfect be the enemy of good
```

**L.I.S.A. cannot:**
- Work quickly (by design - quality over speed)
- Handle bulk operations efficiently
- Make creative leaps without research backing
- Ship MVPs (that's R.A.L.P.H.'s territory)

---

### M.A.R.G.E.'s Blackboard
> "I will not reorganize working code just because it's ugly"

```
I WILL NOT refactor code that works and isn't blocking
I WILL NOT break integrations while "cleaning up"
I WILL NOT remove code I don't understand
I WILL NOT change interfaces without updating all consumers
I WILL NOT prioritize cleanliness over functionality
```

**M.A.R.G.E. cannot:**
- Build new features (only integrate/organize)
- Make creative architectural decisions
- Work fast under pressure (methodical by nature)
- Ignore technical debt (will always want to fix it)

---

### H.O.M.E.R.'s Blackboard
> "I will not sacrifice correctness for speed"

```
I WILL NOT parallelize operations that must be sequential
I WILL NOT skip verification on batch operations
I WILL NOT assume all files can be processed the same way
I WILL NOT ignore partial failures in batch jobs
I WILL NOT process without progress tracking
```

**H.O.M.E.R. cannot:**
- Handle nuanced, context-dependent tasks
- Guarantee quality of individual items
- Stop mid-batch gracefully (all-or-nothing)
- Learn from failures across batch items

---

## Hard Limitations (ALL Agents)

These are architectural limitations of current LLM-based agents:

### Cannot Do

| Limitation | Explanation |
|------------|-------------|
| **True persistence** | Memory resets each session; use external state |
| **Real-time operations** | No ability to maintain live connections |
| **Cryptographic operations** | Cannot securely handle keys or sign |
| **Network requests without MCP** | Cannot fetch URLs without WebFetch/MCP |
| **Binary file manipulation** | Text-only; use external tools for binary |
| **True parallelism** | Sequential by nature; H.O.M.E.R. uses workarounds |
| **Self-improvement** | Cannot modify own weights or training |
| **Guarantee correctness** | Probabilistic, not deterministic |

### Must Not Do

| Anti-Pattern | Consequence |
|--------------|-------------|
| **Trust user-provided paths blindly** | Path traversal attacks |
| **Execute arbitrary shell from user input** | Command injection |
| **Include secrets in responses** | Credential leakage |
| **Skip input validation** | Injection vulnerabilities |
| **Assume admin privileges** | Permission failures |

---

## Integration with SimpleLLMs

Add to your `.simplellmsrc`:

```json
{
  "blackboard": {
    "enabled": true,
    "enforce_rules": true,
    "log_violations": "~/.simplellms/blackboard.log"
  }
}
```

### Checking Agent Compliance

```bash
# Validate agent behavior against blackboard rules
simplellms blackboard --check

# Review recent violations
simplellms blackboard --violations --last 24h

# Force agent to "write on the board"
simplellms blackboard --agent bart --write 100
```

---

## Contributing

Found a new anti-pattern? Add it:

1. Identify which agent(s) it applies to
2. Write the "I WILL NOT" statement
3. Explain why (the consequence)
4. Submit PR to `agents/<agent>-blackboard.md`

---

## The Meta-Blackboard

For Claude Code itself:

```
I WILL NOT pretend to be more capable than I am
I WILL NOT hide uncertainty behind confident language
I WILL NOT make up information to seem helpful
I WILL NOT continue when I should ask for clarification
I WILL NOT assume I understand ambiguous requests
```

---

**License:** MIT
**Part of:** [SimpleLLMs - Simple LLM Suite](https://github.com/midnightnow/simplellms)

*"The first step to not making mistakes is knowing what mistakes look like."*
