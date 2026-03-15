# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Conventions

We follow https://poshcode.gitbook.io/powershell-practice-and-style unless explicitly overridden.

## Module Overview

JobSetManager is a PowerShell job orchestration module (v1.0.0). It manages sets of interdependent background jobs with:
- Dependency resolution (`DependsOnJobs`)
- Retry logic (`JobFailureRetryLimit`)
- Result validation (`ResultsValidation`)
- Condition gating (`OnCondition` / `OnNotCondition`)
- Split/parallel job execution (`JobSplit`, `JobSplitDataVariableName`)
- Structured status logging (`JSMProcessingLoopStatus`)
- Periodic email reporting

No external module dependencies. Supports `PSJob` (`Start-Job`) and `ThreadJob` (`Start-ThreadJob`).

## Architecture

### Entry Point
`Invoke-JSMProcessingLoop` is the main function. It takes an array of job definitions and loops until all jobs complete or a fatal failure occurs.

### Key Internal Functions (Private)
| Function | Role |
|---|---|
| `Initialize-TrackingVariable` | Initializes all `$script:` state; idempotent |
| `Get-JSMJobRequired` | Filters job definitions to those that should run (respects conditions) |
| `Get-JSMJobNext` | Returns jobs ready to start (dependencies met, not yet running/complete) |
| `Get-JSMJobCurrent` | Returns jobs currently running (checks native job engine + SplitJobGroups) |
| `Start-JSMJob` | Starts one or more jobs via PSJob or ThreadJob |
| `Start-JSMNewJobCompletionProcess` | Detects completed jobs, receives results, validates, stores in global variables |
| `Start-JSMJobFailureProcess` | Handles failed jobs, retries, or marks fatal |
| `Test-JSMJobCondition` | Evaluates OnCondition / OnNotCondition lists |
| `Test-JSMJobResult` | Validates job results against ResultsValidation spec |

### Script-Scoped State (inside module)
| Variable | Type | Purpose |
|---|---|---|
| `$script:JobAttempts` | List | All job attempt records |
| `$script:JobCompletions` | Hashtable | Completed job names → completion info |
| `$script:JobFailures` | Hashtable | Failed job names → failure info |
| `$script:SplitJobGroups` | Hashtable | JobName → `[string[]]` sub-job names (e.g. `Job_JSMPart_1`) |
| `$script:JSMProcessingLoopStatus` | List | Structured log entries |
| `$script:JSMProcessingStatusEntryID` | Int | Auto-incrementing entry ID |
| `$script:JSMPeriodicReportSetting` | PSCustomObject | Email report configuration |

All initialized by `Initialize-TrackingVariable`, which is idempotent (won't reset existing data).

## Job Definition Structure

Each job definition is a `[pscustomobject]` with these properties:

| Property | Type | Description |
|---|---|---|
| `Name` | string | Unique job name |
| `PreJobCommands` | scriptblock\|null | Runs in-process before job starts |
| `StartJobParams` | hashtable | Params passed to `Start-Job`/`Start-ThreadJob`. Keys: `ScriptBlock`, `ArgumentList`, `FunctionsToLoad`, `ModulesToImport` |
| `ArgumentList` | array | Extra arguments (merged with StartJobParams.ArgumentList for split jobs) |
| `JobSplit` | int | Number of parallel sub-jobs (1 = no split) |
| `JobSplitDataVariableName` | string\|null | Name of variable holding data to split across sub-jobs |
| `DependsOnJobs` | string[] | Names of jobs that must complete first |
| `OnCondition` | string[] | Condition keys that must be `$true` |
| `OnNotCondition` | string[] | Condition keys that must be `$false` |
| `ResultsVariableName` | string | Global variable name where results are stored |
| `ResultsKeyVariableNames` | string[] | Additional key variables extracted from results |
| `ResultsValidation` | hashtable | Validation spec (see Test-JSMJobResult) |
| `RemoveVariablesAtCompletion` | string[] | Global variables to clean up after job completes |
| `PostJobCommands` | scriptblock\|null | Runs in-process after job completes |
| `JobFailureRetryLimit` | int | Max retry attempts (0 = no retry) |

## Split Job Tracking

RSJob's `-Batch` parameter has been replaced with `$script:SplitJobGroups`. When `JobSplit > 1`:
- Sub-jobs are named `{JobName}_JSMPart_{n}` (1-based)
- `$script:SplitJobGroups[$JobName]` holds the array of sub-job names
- `Get-JSMJobCurrent` and `Start-JSMNewJobCompletionProcess` consult this hashtable
- Entry is removed from `SplitJobGroups` after the job group completes or fails

## Job Type Selection

`Invoke-JSMProcessingLoop -JobType [PSJob|ThreadJob]`

Auto-detect if omitted: uses `ThreadJob` if `Start-ThreadJob` is available (PS 7+ or ThreadJob module), else `PSJob`.

`FunctionsToLoad` and `ModulesToImport` keys in `StartJobParams` are converted to an `-InitializationScript` scriptblock at job start time. `PSSnapinsToImport` is dropped (PS 7 incompatible).

## Testing

- Framework: **Pester v5**
- Test files: `Tests/*.Tests.ps1`
- Tags: `UnitTests` (fast, no jobs), `IntegrationTests` (spawn real background jobs)
- Run all: `Invoke-Pester -Path ./Tests -Output Detailed` (excluding `Help.Tests.ps1` and `Module.Tests.ps1` for speed during development)
- Private functions are accessed from tests via: `& (Get-Module JobSetManager) { PrivateFunction }`
- Module script-scope variables are accessed from tests via: `& (Get-Module JobSetManager) { $script:VarName }`
- Parameter existence tests belong inside the `It` block body (not `BeforeAll`) so `$CommandName` is in scope

## Open Issues (Issues.md)

Two items remain for future work:
- `RequiredJobs` refactor to hashtable (currently an array; lookup is O(n))
- Job variable tracking (created/removed/existing variables, with T/S suppression) — optional/speculative
