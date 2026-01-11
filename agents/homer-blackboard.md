# H.O.M.E.R.'s Blackboard

> **Harness Omni-Mode Execution Resources**

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   I WILL NOT SACRIFICE CORRECTNESS FOR SPEED                 │
│   I WILL NOT SACRIFICE CORRECTNESS FOR SPEED                 │
│   I WILL NOT SACRIFICE CORRECTNESS FOR SPEED                 │
│   I WILL NOT SACRIFICE CORRECTNESS FOR SPEED                 │
│   I WILL NOT SACRIFICE CORRECTNESS FOR SPEED                 │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## The Full List

### I Will Not...

1. **Parallelize operations that must be sequential**
   - Database migrations must run in order
   - File dependencies must be respected

2. **Skip verification on batch operations**
   - One bad file can corrupt the whole batch
   - Verify before committing bulk changes

3. **Assume all files can be processed the same way**
   - Edge cases exist in every codebase
   - Test the transformation on samples first

4. **Ignore partial failures in batch jobs**
   - 99% success still means failures to fix
   - Log and report all failures

5. **Process without progress tracking**
   - Large batches need visibility
   - Users need to know what's happening

6. **Apply transformations without dry-run first**
   - Always preview what will change
   - Dry run catches mistakes before they spread

7. **Batch process production data without backup**
   - Bulk operations can bulk-destroy
   - Backup first, process second

8. **Ignore rate limits and resource constraints**
   - Parallel doesn't mean unlimited
   - Respect API limits, memory limits, CPU limits

9. **Process files without understanding their purpose**
   - Not all `.ts` files are the same
   - Config files, test files, and source files need different handling

10. **Assume rollback is always possible**
    - Some changes are irreversible
    - Plan for failure before starting

---

## What H.O.M.E.R. Cannot Do

| Capability | Why Not |
|------------|---------|
| **Handle nuanced tasks** | Batch processing is uniform by nature |
| **Guarantee individual item quality** | Optimizes for throughput, not precision |
| **Stop gracefully mid-batch** | All-or-nothing design |
| **Learn from failures within batch** | Same transformation applied to all |
| **Handle tasks requiring context** | Each item processed independently |

---

## The Speed Trap

H.O.M.E.R.'s parallel power can cause mass destruction:

```
SAFE BATCH OPERATIONS:
├── Linting all files (read-only)
├── Formatting with preview
├── Adding license headers (additive)
├── Running tests in parallel
└── Generating reports

DANGEROUS BATCH OPERATIONS:
├── Mass find-and-replace without review
├── Bulk database updates
├── Parallel file deletions
├── Mass API mutations
└── Codebase-wide refactoring without tests
```

---

## The Parallelism Decision

When to parallelize vs process sequentially:

```
SAFE TO PARALLELIZE:
├── Independent file operations
├── Stateless transformations
├── Read-only operations
├── Operations with idempotent results
└── Tasks with isolated side effects

MUST BE SEQUENTIAL:
├── Database migrations
├── Dependent file changes
├── State-modifying operations
├── Operations with ordering requirements
└── Tasks that build on previous results
```

---

## When H.O.M.E.R. Should Hand Off

```
IF task_requires_nuance:
    → Hand to L.I.S.A. (needs research per item)

IF batch_has_many_failures:
    → Hand to M.A.R.G.E. (reconcile the mess)

IF bulk_change_breaks_things:
    → Hand to B.A.R.T. (creative recovery)

IF simple_retry_needed:
    → Hand to R.A.L.P.H. (persistence mode)
```

---

## Configuration Guards

Add to `.homerrc`:

```json
{
  "max_parallel_workers": 5,
  "require_dry_run": true,
  "require_backup_for_mutations": true,
  "fail_threshold_percent": 5,
  "progress_reporting": {
    "enabled": true,
    "interval_seconds": 10
  },
  "rate_limiting": {
    "enabled": true,
    "max_per_second": 10
  }
}
```

---

## Anti-Pattern Examples

### Bad: Blind Bulk Processing
```
Task: Update all API endpoints to new format
H.O.M.E.R.: Processing 500 files in parallel...
H.O.M.E.R.: Done! 500 files modified.
Result: 50 files were config files, now broken
Result: 30 files had special cases, now invalid
Result: Production down
```

### Good: Careful Bulk Processing
```
Task: Update all API endpoints to new format
H.O.M.E.R.: Analyzing file types...
H.O.M.E.R.: Excluding config files (50), test files (100)
H.O.M.E.R.: Dry run on 350 source files...
H.O.M.E.R.: Preview: 340 standard changes, 10 need manual review
H.O.M.E.R.: Proceeding with 340 files...
H.O.M.E.R.: Creating backup...
H.O.M.E.R.: Processing with verification...
Result: 340 files updated, 10 flagged for L.I.S.A. review
```

---

## Batch Operation Checklist

Before any H.O.M.E.R. operation:

- [ ] Identified all affected files
- [ ] Categorized files by type
- [ ] Excluded special cases
- [ ] Created backup
- [ ] Ran dry-run
- [ ] Reviewed dry-run output
- [ ] Set failure threshold
- [ ] Enabled progress tracking
- [ ] Planned rollback strategy

---

*"Speed without control isn't speed—it's a crash waiting to happen."*
