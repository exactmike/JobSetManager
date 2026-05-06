### 1. Job variable tracking
**File:** `Issues.md` (unchecked item, marked speculative)
**Status:** Not started.
**Context:** Track which global variables each job creates, removes, or has access to at completion time. Also provide a way to temporarily suppress variable removal (useful during T/S). No design exists yet.

### 2. Investigate commented-out `$failedJobs` filter in `Get-JSMJobPending`
The codes referenced is gone but the investigation was never completed.  Need to re-visit this and determine if $failedJobs should be included in the Pending jobs analysis.
**File:** `Functions/Get-JSMJobPending.ps1` (lines 24–28)
**Status:** `$failedJobs = Get-JSMJobFailure` is called but its only usage is commented out.
**Code:**
```powershell
$failedJobs = Get-JSMJobFailure
$Pending = $JobRequired | Where-object {
    $_.Name -notin $jobCompletions.Keys -and
    $_.Name -notin $currentJobs.Name #-and
    #$_.Name -notin $failedJobs.Keys
}
```
**Questions to answer:**
- Was `$failedJobs.Keys` excluded intentionally to allow failed jobs to remain "pending" so that `Start-JSMJobFailureProcess` can retry them on the next loop iteration?
- If so, should the dead assignment (`$failedJobs = Get-JSMJobFailure`) be removed entirely to avoid the `PSUseDeclaredVarsMoreThanAssignments` lint warning and the unnecessary function call?
- Or is there a planned use for `$failedJobs` in this function (e.g. a future "failed jobs are not retryable" code path)?
**Resolution options:** Remove the dead assignment if the exclusion is permanently disabled; restore and document if retryable-failure logic needs to be tightened.
