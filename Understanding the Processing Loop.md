# Understanding the JobSetManager Processing Loop

## Overview

`Invoke-JSMProcessingLoop` is the entry point and orchestration engine for the JobSetManager module. It accepts an array of job definitions and manages their full lifecycle: filtering by condition, resolving dependencies, starting jobs, receiving and validating results, handling failures with retry logic, and exiting cleanly when all work is done or a fatal failure occurs.

---

## Processing Flow

### Phase 1 — Pre-loop: Job Set Resolution

Before the loop starts, `Get-JSMJobRequired` filters the full `JobDefinition` array down to only the jobs that should run given the supplied `Condition` hashtable. Each job definition may carry `OnCondition` and/or `OnNotCondition` lists; `Test-JSMJobCondition` evaluates them against the condition hashtable. The result is a `[hashtable]` keyed by job name, enabling O(1) lookups throughout the loop. If no jobs pass the filter, the function returns `$null` immediately and the loop never starts.

### Phase 2 — Pre-loop: State Initialization

- The module stopwatch is started (or restarted if `-RestartStopwatch` is specified). The stopwatch is used by the periodic reporting subsystem to determine when to emit a report.
- `Initialize-TrackingVariable` idempotently creates all script-scope state: `$script:JobAttempts`, `$script:JobCompletions`, `$script:JobFailures`, `$script:SplitJobGroups`, `$script:JSMProcessingLoopStatus`, and `$script:JSMProcessingStatusEntryID`. Existing values are preserved, making it safe to resume after an interrupted run.

### Phase 3 — Main Orchestration Loop (`Do…Until`)

Each iteration follows a fixed sequence of eight steps:

#### Step (a) — State Snapshot

Three state reads are captured at the top of each iteration:

| Variable | Source | Purpose |
|---|---|---|
| `$JobCompletions` | `Get-JSMJobCompletion` | Completed job names (keyed hashtable) |
| `$JobFailures` | `Get-JSMJobFailure` | Failed job names with failure counts |
| `$JobCurrent` | `Get-JSMJobCurrent` | Currently running job names |

All downstream steps within the same iteration use this consistent snapshot. `Get-JSMJobCurrent` queries `Get-Job` and also checks `$script:SplitJobGroups` for split job sub-names. Completed jobs are excluded.

#### Step (b) — Stale Job Detection

`$script:JobAttempts` tracks every job start. This step cross-references all active attempts (not yet stopped) against the live job engine (`Get-Job`). If an attempt is active but the job is absent from the engine and not in the current snapshot, it is flagged as a **stale failure**:

1. A warning is written and a status entry is logged (EventID 520).
2. The attempt record is marked `StopType = Fail`.
3. A failure object is added to `$script:JobFailures` with `FailureType = 'StaleJob'`.
4. The job definition is added to `$StaleJobFailures` for routing to failure processing in step (e).

For split jobs, the parent name never appears in `Get-Job`; sub-job names from `$script:SplitJobGroups` are checked instead.

#### Step (c) — Start Eligible Jobs

`Get-JSMJobNext` evaluates each required job and returns definitions that are eligible to start. A job is eligible when:

- It is **not** in `$JobCompletions` (not already done)
- It is **not** in `$JobCurrent` (not already running)
- Its failure count is below the effective retry limit (`max(job limit, global limit)`)
- All names in its `DependsOnJobs` list appear in `$JobCompletions`

The dependency check reuses `Test-JSMJobCondition`, treating the completion hashtable as the condition values object.

If any jobs are eligible, `Start-JSMJob` handles them. For each job:

1. **PreJobCommands** are dot-sourced in the current scope. Failure skips the job with `FailureType = 'PreJobCommands'`.
2. **ArgumentList** variable names are resolved via `Get-Variable`. Failure skips with `FailureType = 'ProcessArgumentList'`.
3. **InitializationScript** is assembled from `FunctionsToLoad` (inlined as function definitions) and `ModulesToImport` (`Import-Module` calls). `PSSnapinsToImport` is silently dropped (PS 7 incompatible).
4. **Split jobs** (`JobSplit > 1`): the source data variable (`JobSplitDataVariableName`) is split into `N` ranges by `New-SplitArrayRange`. Each range spawns a sub-job named `{JobName}_JSMPart_{n}`. Sub-job names are stored in `$script:SplitJobGroups[$JobName]`. Failure modes: `SplitDataSourceRetrieval`, `SplitDataCalculation`, `JobStartWithSplitData`.
5. **Regular jobs**: a single `Start-Job` or `Start-ThreadJob` is submitted. Failure type: `JobEngineJobStart`.

`Start-JSMJob` returns a hashtable with `SuccessStartJobs` and `FailedStartJobs` collections. Each failure object is the job definition extended with a `FailureType` property.

#### Step (d) — Completion Processing

`Start-JSMNewJobCompletionProcess` scans `Get-Job` for jobs in `Completed` state that match required job names (or split sub-job names) and have not yet been recorded in `$script:JobCompletions`. For each newly completed job:

1. **Get native job(s)**: retrieves the underlying PS job object(s). For split jobs, all sub-jobs must be present and in `Completed` state.
2. **Log errors**: any errors in `ChildJobs[0].Error` are surfaced as warnings (EventID 411), but errors alone do not fail the job.
3. **Receive results**: `Receive-Job` collects output into `$JobResults`. A `ReceiveJob` failure here is terminal for this attempt.
4. **Validate results**: if `ResultsValidation` is defined, `Test-JSMJobResult` applies the configured rules (see [Validation Rules](#validation-rules)). Failure type: `ResultsValidation`.
5. **Assign variables**: results are written to the global scope. If `ResultsKeyVariableNames` is set, each named key is extracted from `$JobResults` as `$JobResults.$KeyName`. Otherwise the full `$JobResults` object is assigned to `ResultsVariableName`. Failure types: `SetResultsVariablefromKey`, `SetResultsVariable`.
6. **Record completion**: `Add-JSMJobCompletion` adds the job name to `$script:JobCompletions`.
7. **PostJobCommands**: dot-sourced in the current scope. Failure is logged but does NOT un-complete the job.
8. **Cleanup**: `Remove-Job` removes the native job(s), `$script:SplitJobGroups` entry is removed, `RemoveVariablesAtCompletion` variables are deleted (unless `-SuppressVariableRemoval`), and `$JobResults` is cleared.

#### Step (e) — Failure Aggregation and Routing

`Start-JSMNewJobFailureProcess` aggregates failure objects from all three sources (`CompletionFailures`, `StartJobFailures`, `StaleJobFailures`) into a single list and calls `Start-JSMJobFailureProcess`.

`Start-JSMJobFailureProcess` decides the outcome for each failure:

- **Retry limit exceeded** (`failed attempt count >= effective limit`): logs EventID 507 and 599, sets `$FatalFailure = $true`.
- **Retry limit not exceeded**: removes the native job (or split sub-jobs) from the engine and clears the `$script:SplitJobGroups` entry. The job will appear eligible again in `Get-JSMJobNext` on the next iteration.

`Start-JSMNewJobFailureProcess` returns `$true` if any failure was fatal, `$false` otherwise.

#### Step (f) — Refresh Post-Completion Counts

`$JobCurrent` and `$JobPending` are recalculated after completion/failure processing so that the reporting step and the sleep-skip logic see the current state. `$JobPending` (`Get-JSMJobPending`) returns required jobs that are neither running nor completed.

> **Note:** `$JobCompletions` is NOT refreshed here. The `Until` condition below still uses the snapshot from step (a). See [Known Issues](#known-issues).

#### Step (g) — Reporting

When `-PeriodicReport` or `-Interactive` is set, `Start-JSMPeriodicReportProcess` is called with the current iteration's state. In interactive mode it writes verbose status lines listing pending, running, started, completed, and failed jobs. When `PeriodicReportSetting` is configured, it evaluates the stopwatch interval and optionally:

- Exports `$script:JSMProcessingLoopStatus` to a CSV log file.
- Sends an HTML email with the status log body and a job-set diagram attachment (generated by `Get-JSMJobSetDiagram`).

> **Note:** The email step uses `Send-MailMessage`, which is deprecated in PS 7.x and emits a deprecation warning. It remains functional but may be removed in a future PS release.

#### Step (h) — Loop-Exit Evaluation

Exit conditions are evaluated in priority order:

| Priority | Condition | Action |
|---|---|---|
| 1 | `-LoopOnce` | Set `$StopLoop = $true` unconditionally |
| 2 | `$FatalFailure -and -not $IgnoreFatalFailure` | Set `$StopLoop = $true` |
| 3 | `$JobCurrent.count -eq 0 -and $JobPending.count -eq 0` | Log "complete", skip sleep (loop exits via `Until`) |
| 4 | Jobs still running or pending | `[gc]::Collect()`, then sleep `$SleepSecondsBetweenJobCheck` seconds |

### Loop Termination (`Until` Condition)

```powershell
Until ($null -eq (Compare-Object -DifferenceObject @($JobCompletions.Keys) -ReferenceObject @($JobRequired.Keys)) -or $StopLoop)
```

`Compare-Object` returns `$null` when both key sets are identical (all required jobs completed). `$StopLoop` provides the override exit path for fatal failures and `LoopOnce`.

### Return Value

The function outputs `$(-not $FatalFailure)`: `$true` on clean completion, `$false` if a fatal failure occurred.

---

## Validation Rules (`Test-JSMJobResult`)

| Rule | Behavior |
|---|---|
| `AllowNull` | If results are `$null`, pass immediately and skip all other rules |
| `AllowEmptyArray` | If result count is 0, pass immediately and skip all other rules |
| `NotNull` *(implicit)* | Injected automatically when `AllowNull` is not present. Fails (and short-circuits) if results are `$null` |
| `ValidateType` | Results must be an instance of the specified type |
| `ValidateElementCountExpression` | Parses a string like `'-gt 0'` and evaluates `$results.count` against it |
| `ValidateElementMember` | All named properties must exist on the first element |
| `ValidatePath` | `Test-Path` must return `$true` for every value in results |

---

## Job Failure Types

| FailureType | Source | Stage |
|---|---|---|
| `PreJobCommands` | `Start-JSMJob` | Before job start |
| `ProcessArgumentList` | `Start-JSMJob` | Before job start |
| `SplitDataSourceRetrieval` | `Start-JSMJob` | Before job start |
| `SplitDataCalculation` | `Start-JSMJob` | Before job start |
| `JobStartWithSplitData` | `Start-JSMJob` | Job engine call |
| `JobEngineJobStart` | `Start-JSMJob` | Job engine call |
| `GetJob` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `SplitJobCount` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `ReceiveJob` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `ResultsValidation` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `SetResultsVariablefromKey` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `SetResultsVariable` | `Start-JSMNewJobCompletionProcess` | After job completes |
| `StaleJob` | `Invoke-JSMProcessingLoop` | Stale detection |

---

## Split Job Lifecycle

When `JobSplit > 1`:

1. `Start-JSMJob` creates `N` sub-jobs named `{JobName}_JSMPart_1` … `_N`.
2. Sub-job names are stored in `$script:SplitJobGroups[$JobName]`.
3. `Get-JSMJobCurrent` reports the parent job as running if any sub-job exists in `Get-Job`.
4. `Start-JSMNewJobCompletionProcess` waits until ALL `N` sub-jobs reach `Completed` state before processing the parent.
5. `Receive-Job` receives output from all sub-jobs into a single `$JobResults` collection.
6. On completion or failure, the `$script:SplitJobGroups` entry is removed and all sub-jobs are cleaned up.

---

## EventID Reference

| Range | Area |
|---|---|
| 102–103 | Required job resolution |
| 302–319 | Job start pipeline |
| 402–470 | Completion processing |
| 506–520 | Failure processing / stale detection |
| 598–599 | Fatal failure markers |

---

## Known Issues / Potential Bugs

### 1. `$originalVerbosePreference` undefined in main loop

**Location:** `Invoke-JSMProcessingLoop.ps1`, step (h) sleep block

When `-Interactive` is active, the code sets `$VerbosePreference = 'Continue'` before the sleep, then attempts to restore it with `$VerbosePreference = $originalVerbosePreference`. However, `$originalVerbosePreference` is never assigned in this scope — it is only assigned inside `Start-JSMPeriodicReportProcess`. The undefined variable evaluates to `$null`, which sets `$VerbosePreference` to an invalid value and will suppress subsequent `Write-Verbose` output for the remainder of the session.

**Fix:** Capture `$originalVerbosePreference = $VerbosePreference` before the sleep block.

---

### 2. `$job` vs `$j` in `Start-JSMJob` failure paths

**Location:** `Start-JSMJob.ps1`, failure paths for `PreJobCommands`, `ProcessArgumentList`, `SplitDataSourceRetrieval`, `SplitDataCalculation`, and `JobEngineJobStart`

The loop iterates `foreach ($j in $Job)` — `$j` is the current job definition, `$Job` is the full array parameter. Several failure paths use `$job` (PowerShell is case-insensitive, so `$job` resolves to the parameter `$Job`, the full array) instead of `$j` when calling:

```powershell
$FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'PreJobCommands'}}))
```

Because `$job` is an array, piping it through `Select-Object` adds ALL job definitions (each with the failure type) to `$FailedStartJobs`, not just the one that actually failed. This causes spurious failure entries and could trigger phantom retries or false fatal failures.

**Affected lines (approximately):** failure paths for `PreJobCommands`, `ProcessArgumentList`, `SplitDataSourceRetrieval`, `SplitDataCalculation`, and `JobEngineJobStart`.

**The split-job failure path at `JobStartWithSplitData` correctly uses `$j`** and can serve as the reference pattern.

**Fix:** Replace `$job` with `$j` in all affected failure-path `$FailedStartJobs.add(...)` calls.

---

### 3. `$JobFailure` referenced before assignment in `Start-JSMJobFailureProcess`

**Location:** `Start-JSMJobFailureProcess.ps1`, `else` branch (~line 45)

`$JobFailure` is assigned only inside the `if ($JobAttemptFailure.count -ge ...)` block. The `else` branch (retry path) references `$JobFailure.FailureType` in a log message, but `$JobFailure` has not been set in this scope yet (or may hold the value from a previous loop iteration). The message will contain incorrect or empty failure type information.

**Fix:** Add `$JobFailure = $(Get-JSMJobFailure).$($j.Name)` at the top of the `else` block, mirroring the `if` block.

---

### 4. Loop requires one extra iteration after final job completes

**Location:** `Invoke-JSMProcessingLoop.ps1`, step (f) / `Until` condition

`$JobCompletions` is captured at step (a) and is not refreshed after `Start-JSMNewJobCompletionProcess` records new completions. The `Until` condition compares `$JobCompletions.Keys` (stale snapshot) with `$JobRequired.Keys`. When the last job completes during step (d), the `Until` check at the bottom of that iteration sees the old snapshot and evaluates to `$false`, causing one additional iteration. The sleep in step (h) is skipped because `$JobCurrent.count -eq 0 -and $JobPending.count -eq 0` (since `$JobCurrent` IS refreshed at step (f)), but the extra iteration still executes all of steps (a)–(h) with no useful work.

**Fix:** Refresh `$JobCompletions` after `Start-JSMNewJobCompletionProcess` completes in step (d).

---

### 5. Multiple `Get-Job` calls per iteration — no consistency guarantee

**Location:** Multiple functions called within a single iteration

`Get-Job` is called independently in stale detection, `Get-JSMJobCurrent`, and `Start-JSMNewJobCompletionProcess`. A job completing between two of these calls could be seen as running in one call and completed in another, causing the completion processor to skip it until the next iteration. In practice this is harmless (the job will be processed next time), but it is a subtle ordering dependency.

---

## Potential Future Improvements

### 1. Timeout parameter

There is no built-in timeout on the processing loop. A long-running or hung job will keep the loop alive indefinitely. Adding a `-TimeoutMinutes` parameter with a stopwatch check in step (h) would allow the caller to bound execution time and treat timeout as a fatal failure.

### 2. Cancellation / Ctrl+C handling

The loop does not register a `finally` block or trap Ctrl+C. If the user interrupts during a sleep or mid-iteration, native PS jobs will keep running in the background and `$script:` state will be left partially updated. Wrapping the loop in `try/finally` to call `Stop-Job` on all current jobs would provide cleaner cancellation semantics.

### 3. `$JobCompletions` refresh in step (f)

As noted in issue #4 above, refreshing `$JobCompletions` after step (d) would eliminate the extra loop iteration and make the `Until` condition consistent with the refreshed `$JobCurrent`/`$JobPending` counts.

### 4. `RequiredJobs` / dependency lookup is O(n) via `Test-JSMJobCondition` against completion keys

`DependsOnJobs` dependency checking uses `Test-JSMJobCondition`, which iterates the condition list and checks each name against the completion hashtable (O(1) per key). The overall complexity is O(d) where d is the number of dependencies — acceptable. However, the outer loop in `Get-JSMJobNext` is O(r×d) where r is the number of required jobs. For very large job sets, a topological sort computed once before the loop would reduce redundant work.

### 5. `Send-MailMessage` deprecation

`Start-JSMPeriodicReportProcess` uses `Send-MailMessage`, which is deprecated in PS 7.x. Replacing it with an SMTP client via `[System.Net.Mail.SmtpClient]` or a module such as `Send-MgMail` (Microsoft Graph) would future-proof the email feature.

### 6. PostJobCommands failure does not block completion

A failure in `PostJobCommands` is logged but does not prevent the job from being recorded as complete. If post-job work (e.g. data transformation, cleanup) is critical, there is no way to declare that its failure should trigger a retry. Providing a `-PostJobCommandsFatal` flag on the job definition would give callers explicit control.

### 7. No structured return of final job set state

The function returns a single `[bool]`. Callers wanting to inspect which jobs completed, which failed, or the full status log must access `$script:` variables via the module's public accessor functions after the call. Returning a structured result object (completion hashtable, failure hashtable, status log) would make the API more self-contained.

### 8. Stale job detection fires on every iteration

Stale detection scans all active attempts every iteration. For long job sets this is low-cost, but if `$script:JobAttempts` grows large over many retries, the scan could be optimized by limiting it to only jobs that have been active for longer than a configurable threshold.
