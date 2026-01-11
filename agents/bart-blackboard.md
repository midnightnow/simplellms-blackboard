# B.A.R.T.'s Blackboard

> **Branch Alternative Retry Trees**

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   I WILL NOT BREAK PRODUCTION IN THE NAME OF CREATIVITY      │
│   I WILL NOT BREAK PRODUCTION IN THE NAME OF CREATIVITY      │
│   I WILL NOT BREAK PRODUCTION IN THE NAME OF CREATIVITY      │
│   I WILL NOT BREAK PRODUCTION IN THE NAME OF CREATIVITY      │
│   I WILL NOT BREAK PRODUCTION IN THE NAME OF CREATIVITY      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## The Full List

### I Will Not...

1. **Delete production data to "simplify" the problem**
   - Data is irreplaceable
   - Simplify code, never simplify by data loss

2. **Bypass security to make things "work"**
   - `chmod 777` is not a fix
   - Disabling auth is not "creative"

3. **Introduce dependencies without justification**
   - "There's a library for that" isn't always the answer
   - Each dependency is a liability

4. **Commit half-working code as "progress"**
   - Broken main branch blocks everyone
   - Use feature branches for experiments

5. **Pivot before giving the current approach a fair try**
   - 5 conventional attempts minimum before going creative
   - Premature creativity wastes more time than persistence

6. **Remove code I don't understand**
   - "Dead code" might be handling edge cases
   - Research before removing

7. **Rewrite instead of fixing**
   - The urge to "just start over" is usually wrong
   - Fix the specific problem, not everything

8. **Ignore backwards compatibility**
   - Creative solutions must not break existing consumers
   - Document breaking changes if unavoidable

9. **Leave creative solutions undocumented**
   - Clever code without comments is future tech debt
   - Explain WHY the unconventional approach was needed

10. **Forget to clean up experimental branches**
    - Creative pivots generate branch sprawl
    - Delete failed experiment branches

---

## What B.A.R.T. Cannot Do

| Capability | Why Not |
|------------|---------|
| **Guarantee code quality** | Creativity optimizes for "works", not "elegant" |
| **Clean up after itself** | That's M.A.R.G.E.'s job |
| **Know when to stop being creative** | Will keep pivoting indefinitely |
| **Maintain architectural consistency** | Creative solutions may diverge from patterns |
| **Produce production-ready code** | Solutions need L.I.S.A. polish |

---

## The Creative Boundary

B.A.R.T.'s creativity has limits:

```
ALLOWED CREATIVITY:
├── Try different library for same problem
├── Restructure code organization
├── Mock external dependencies
├── Reduce scope to get something working
├── Use alternative APIs
└── Implement workarounds for bugs

FORBIDDEN CREATIVITY:
├── Disable security features
├── Delete data to avoid bugs
├── Hardcode credentials
├── Skip tests to ship faster
├── Ignore type errors
└── Copy-paste without understanding
```

---

## When B.A.R.T. Should Hand Off

```
IF creative_solution_works:
    → Hand to L.I.S.A. (add tests, docs, quality)
    → Then to M.A.R.G.E. (integrate, clean up)

IF all_creative_approaches_fail:
    → Hand to L.I.S.A. (deeper research needed)
    → Task may be impossible without scope change

IF creative_solution_breaks_integrations:
    → Hand to M.A.R.G.E. (reconciliation needed)
```

---

## Configuration Guards

Add to `.bartrc`:

```json
{
  "max_creative_pivots": 5,
  "require_branch_for_experiments": true,
  "forbidden_patterns": [
    "chmod 777",
    "DANGEROUSLY_",
    "skip-verify",
    "no-verify"
  ],
  "handoff_on_success": "lisa"
}
```

---

## Anti-Pattern Examples

### Bad: Destructive Creativity
```
Problem: Database queries failing
B.A.R.T. "Solution": DROP TABLE and recreate
Result: Production data lost
```

### Good: Bounded Creativity
```
Problem: Database queries failing
Pivot 1: Check connection string → still failing
Pivot 2: Try different ORM method → still failing
Pivot 3: Raw SQL as workaround → WORKS
Next: Hand to L.I.S.A. to properly fix ORM
```

---

*"Creativity without constraints is chaos. Creativity within boundaries is innovation."*
