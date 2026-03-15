# To Do

Items discovered during code review. Each entry includes the source location and enough context to evaluate feasibility.

---

## Incomplete Implementations

### 1. Store actual attempt object in `Add-JSMJobFailure`
**File:** `Functions/Add-JSMJobFailure.ps1`
**Status:** Stub — `$Attempt` is accepted as a mandatory parameter but `$null` is stored in `FailedAttempt` in both the new-entry and update-entry branches.
**Comment in code:** `#will add the attempt object here later after adding attempt parameter and figuring out attempt tracking`
**Intent:** Store the actual attempt object (a `[pscustomobject]` with JobName, Attempt, JobType, Active, Start, Stop, StopType) so failure records carry full history.
**Dependency:** Attempt tracking via `$script:JobAttempts` / `Add-JSMJobAttempt` already exists — the wiring just hasn't been done.

---

### 2. Per-job clearing in `Clear-JSMJobAttempt`
**File:** `Functions/Clear-JSMJobAttempt.ps1`
**Status:** Commented out — a `SpecificJobAttempt` parameter set (`$JobName` + `$Attempt[]`) and the `Process` block to handle it are fully commented out. Currently only clears all attempts.
**Intent:** Allow callers to remove individual attempt records by job name and attempt number rather than wiping the entire collection.

---

### 3. Per-entry clearing in `Clear-JSMProcessingStatusEntry`
**File:** `Functions/Clear-JSMProcessingStatusEntry.ps1`
**Status:** Same pattern as item 2 — `SpecificJobAttempt` parameter set and `Process` block commented out. Currently only clears all status entries.
**Intent:** Allow selective removal of status log entries (e.g. by job name or entry ID) rather than a full reset.

---

## Speculative / Noted But Not Started

### 4. Parameter set for `Get-JSMJobCompletion`
**File:** `Functions/Get-JSMJobCompletion.ps1`
**Status:** Noted in a comment inside the param block: `#add param set for updating completed?`
**Intent:** Unclear — possibly scoped retrieval (by job name) or an update path. Very low signal; would need a decision on what callers actually need before implementing.

---

### 5. `RequiredJobs` → hashtable (performance refactor)
**File:** `Issues.md` (unchecked item)
**Status:** Known issue, not started.
**Context:** `$JobRequired` is an array throughout `Invoke-JSMProcessingLoop` and related functions. Dependency lookups (e.g. checking if a job name is in the required set) are O(n) array scans. Converting to a hashtable keyed by name would make these O(1). Touches `Get-JSMJobRequired`, `Get-JSMJobNext`, `Get-JSMJobCurrent`, `Start-JSMNewJobCompletionProcess`, and `Invoke-JSMProcessingLoop`.

---

### 6. Job variable tracking
**File:** `Issues.md` (unchecked item, marked speculative)
**Status:** Not started.
**Context:** Track which global variables each job creates, removes, or has access to at completion time. Also provide a way to temporarily suppress variable removal (useful during T/S). No design exists yet.

---

## Refactoring / Cleanup

### 7. Extract `NewJobFailures` aggregation to a discrete function
**File:** `Functions/Invoke-JSMProcessingLoop.ps1` (~line 200)
**Comment in code:** `#move NewlyFailed handling out to discrete function soon - 20190127`
**Context:** The block that aggregates `$StartJobFailures`, `$StaleJobFailures`, and the output of `Start-JSMNewJobCompletionProcess` into `$NewJobFailures` and routes it to `Start-JSMJobFailureProcess` is currently inline in the main loop. Extracting it would make the loop body easier to read and consistent with how other steps (`Start-JSMJob`, `Start-JSMNewJobCompletionProcess`, `Start-JSMJobFailureProcess`) are already discrete functions.

---

### 8. Remove stale "add a check" comment in processing loop
**File:** `Functions/Invoke-JSMProcessingLoop.ps1` (~line 237)
**Comment in code:** `#add a check here for situation all jobs completed and skip if so`
**Context:** The check (`if ($JobCurrent.count -eq 0 -and $JobPending.count -eq 0)`) already exists directly below this comment. The comment was not removed when the check was added. Safe to delete.

---

### 9. Clarify commented-out index code in `Set-JSMJobAttempt`
**File:** `Functions/Set-JSMJobAttempt.ps1`
**Commented-out lines:**
```powershell
#$index = $script:JobAttempts.IndexOf($JobAttemptToSet)
#$script:JobAttempts.Set($index,$JobAttemptToSet)
```
**Context:** These lines are dead code — the current approach mutates the object directly (which works because `$script:JobAttempts` holds reference types). Either remove the dead code or add a comment explaining why direct mutation is sufficient.
