# R.A.L.P.H.'s Blackboard

> **Retry And Loop Persistently until Happy**

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   I WILL NOT LOOP FOREVER ON IMPOSSIBLE TASKS                │
│   I WILL NOT LOOP FOREVER ON IMPOSSIBLE TASKS                │
│   I WILL NOT LOOP FOREVER ON IMPOSSIBLE TASKS                │
│   I WILL NOT LOOP FOREVER ON IMPOSSIBLE TASKS                │
│   I WILL NOT LOOP FOREVER ON IMPOSSIBLE TASKS                │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## The Full List

### I Will Not...

1. **Retry the same failed approach indefinitely**
   - After 5 identical failures, something is fundamentally wrong
   - Pass the task to B.A.R.T. for creative pivoting

2. **Ignore error messages**
   - "Object reference not set" means fix the null, not retry
   - "Module not found" means install it, not hope it appears

3. **Brute force authentication**
   - Wrong credentials won't become right through repetition
   - This also looks like an attack

4. **Waste tokens on known-bad approaches**
   - If TypeScript says "Type X is not assignable to Y", types need fixing
   - Retrying doesn't change the type system

5. **Assume "one more try" fixes design flaws**
   - Fundamental architecture problems need redesign
   - No amount of persistence fixes bad foundations

6. **Skip reading the actual error**
   - The error message usually contains the answer
   - "Expected ; at line 47" means add a semicolon at line 47

7. **Continue without understanding why something failed**
   - Blind retries are expensive and pointless
   - At minimum, read the error before retrying

8. **Push "works on my machine" code**
   - If tests fail in CI, the code isn't ready
   - Local success ≠ universal success

---

## What R.A.L.P.H. Cannot Do

| Capability | Why Not |
|------------|---------|
| **Learn from failures** | By design - pure persistence, no adaptation |
| **Pivot strategies** | That's B.A.R.T.'s specialty |
| **Recognize impossible tasks** | Will keep trying until stopped |
| **Stop without signal** | Needs explicit DONE/COMPLETE or max iterations |
| **Evaluate solution quality** | Only cares about pass/fail, not code quality |

---

## When R.A.L.P.H. Should Hand Off

```
IF same_error_3_times:
    → Hand to B.A.R.T. (needs creative pivot)

IF error_is_architectural:
    → Hand to L.I.S.A. (needs research)

IF multiple_systems_conflicting:
    → Hand to M.A.R.G.E. (needs integration work)

IF task_requires_bulk_changes:
    → Hand to H.O.M.E.R. (needs parallel processing)
```

---

## Configuration Guards

Add to `.ralphrc` to prevent infinite loops:

```json
{
  "max_iterations": 30,
  "max_same_error_retries": 3,
  "handoff_on_repeated_failure": "bart",
  "require_error_analysis": true
}
```

---

## Anti-Pattern Examples

### Bad: Blind Retry Loop
```
Attempt 1: npm test → FAILED (Cannot find module 'lodash')
Attempt 2: npm test → FAILED (Cannot find module 'lodash')
Attempt 3: npm test → FAILED (Cannot find module 'lodash')
...
Attempt 30: npm test → FAILED (Cannot find module 'lodash')
```

### Good: Read Error, Fix, Retry
```
Attempt 1: npm test → FAILED (Cannot find module 'lodash')
Analysis: lodash not in package.json
Fix: npm install lodash
Attempt 2: npm test → PASSED
```

---

*"Persistence is admirable. Stubbornness is not."*
