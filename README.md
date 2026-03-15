# JobSetManager

PowerShell module for orchestrating sets of interdependent background jobs with dependency resolution, retry logic, result validation, and structured logging.

## Overview

JobSetManager lets you define a set of jobs with dependency relationships and run them in parallel, handling:

- **Dependency resolution** — jobs start only when their prerequisites complete
- **Retry logic** — failed jobs are retried up to a configurable limit
- **Result validation** — validate job output before marking it complete
- **Structured logging** — every state transition is recorded in a queryable log
- **Split jobs** — a single logical job can be split across multiple parallel workers
- **Periodic reporting** — log or email progress at configurable intervals

## Requirements

- **PowerShell 5.1** or **PowerShell 7.x**
- **ThreadJob module** (optional, for `Start-ThreadJob` support on PS 5.1): `Install-Module ThreadJob`
  - PS 7.x includes `Start-ThreadJob` natively — no extra install needed

## Installation

```powershell
Install-Module -Name JobSetManager
```

## Quick Start

```powershell
Import-Module JobSetManager

$jobs = @(
    [pscustomobject]@{
        Name                     = 'GetData'
        DependsOnJobs            = @()
        StartJobParams           = @{ ScriptBlock = { 1..10 } }
        ResultsVariableName      = 'MyData'
        ResultsValidation        = @{ NotNull = $true }
        ResultsKeyVariableNames  = @()
        RemoveVariablesAtCompletion = @()
        OnCondition              = @()
        OnNotCondition           = @()
        PreJobCommands           = $null
        PostJobCommands          = $null
        JobFailureRetryLimit     = 0
        ArgumentList             = @()
        JobSplit                 = 1
        JobSplitDataVariableName = $null
    },
    [pscustomobject]@{
        Name                     = 'ProcessData'
        DependsOnJobs            = @('GetData')
        StartJobParams           = @{ ScriptBlock = { $using:MyData | Measure-Object -Sum } }
        ResultsVariableName      = 'MyResult'
        ResultsValidation        = @{}
        ResultsKeyVariableNames  = @()
        RemoveVariablesAtCompletion = @()
        OnCondition              = @()
        OnNotCondition           = @()
        PreJobCommands           = $null
        PostJobCommands          = $null
        JobFailureRetryLimit     = 0
        ArgumentList             = @()
        JobSplit                 = 1
        JobSplitDataVariableName = $null
    }
)

$success = Invoke-JSMProcessingLoop -JobDefinition $jobs -Interactive
$MyResult
```

## Job Definition Reference

| Property | Type | Description |
|---|---|---|
| `Name` | `string` | Unique job identifier |
| `StartJobParams` | `hashtable` | Parameters splatted to `Start-Job` / `Start-ThreadJob`. Keys: `ScriptBlock`, `ArgumentList`, `FunctionsToLoad`, `ModulesToImport`. |
| `DependsOnJobs` | `string[]` | Names of jobs that must complete before this job starts |
| `OnCondition` | `string[]` | Condition keys that must be `$true` for this job to be included |
| `OnNotCondition` | `string[]` | Condition keys that must be `$false` for this job to be included |
| `ResultsVariableName` | `string` | Name of the global variable to receive job output |
| `ResultsKeyVariableNames` | `string[]` | If output is a hashtable, receive each key into its own variable |
| `ResultsValidation` | `hashtable` | Validation rules applied to job output (see below) |
| `PreJobCommands` | `scriptblock` | Runs in the calling scope before the job starts |
| `PostJobCommands` | `scriptblock` | Runs in the calling scope after the job completes successfully |
| `RemoveVariablesAtCompletion` | `string[]` | Global variable names to remove after job completes |
| `JobFailureRetryLimit` | `int` | Per-job retry limit (overrides the global limit when higher) |
| `JobSplit` | `int` | Number of parallel workers to split the job into |
| `JobSplitDataVariableName` | `string` | Name of the variable containing data to split across workers |
| `ArgumentList` | `string[]` | Variable names to resolve and pass as `ArgumentList` to the job |

### Result Validation Keys

| Key | Type | Description |
|---|---|---|
| `NotNull` | `bool` | Result must not be null (default when no `AllowNull` key present) |
| `AllowNull` | `bool` | Result may be null; skip all other validations if null |
| `AllowEmptyArray` | `bool` | Result may be an empty collection; skip other validations if empty |
| `ValidateType` | `type` | Result must be this type (e.g. `[array]`, `[hashtable]`) |
| `ValidateElementCountExpression` | `string` | Count expression like `'-gt 5'` or `'-eq 10'` |
| `ValidateElementMember` | `string[]` | Result elements must have these property names |
| `ValidatePath` | `bool` | Result must be valid filesystem path(s) |

### FunctionsToLoad and ModulesToImport

To use functions or modules inside a job:

```powershell
StartJobParams = @{
    FunctionsToLoad = @('My-HelperFunction')  # injected via InitializationScript
    ModulesToImport = @('ActiveDirectory')    # imported inside the job
    ScriptBlock     = { My-HelperFunction }
}
```

## Core Concepts

### Dependency Resolution

`DependsOnJobs` lists jobs by name that must be in the completion set before this job is eligible to start. Circular dependencies are not detected — design your job graph as a DAG.

### Retry Logic

If a job fails (start failure, result validation failure, etc.), it is retried on the next loop iteration up to `JobFailureRetryLimit` times. The per-job `JobFailureRetryLimit` and the global limit on `Invoke-JSMProcessingLoop` are compared; the higher value applies.

### Conditions

`OnCondition` and `OnNotCondition` let you conditionally include jobs based on runtime values you pass as the `-Condition` parameter to `Invoke-JSMProcessingLoop`. Jobs whose conditions are not satisfied are excluded from the required job set entirely.

## Working with Split Jobs

Split jobs divide one logical job across multiple parallel workers:

```powershell
[pscustomobject]@{
    Name                     = 'ProcessUsers'
    JobSplit                 = 4          # 4 parallel workers
    JobSplitDataVariableName = 'AllUsers' # splits $AllUsers into 4 chunks
    StartJobParams           = @{
        ScriptBlock = {
            $chunk = $using:YourSplitData  # each worker receives its chunk
            $chunk | ForEach-Object { ... }
        }
    }
    ...
}
```

Sub-jobs are named `{JobName}_JSMPart_1`, `{JobName}_JSMPart_2`, etc. All sub-jobs must complete before the parent job is considered done.

## Monitoring and Reporting

### Interactive Mode

```powershell
Invoke-JSMProcessingLoop -JobDefinition $jobs -Interactive
```

Prints verbose status every loop iteration.

### Periodic Email Reports

```powershell
$settings = Set-JSMPeriodicReportSetting -Units Minutes -Length 15 -SendEmail $true `
    -To 'ops@example.com' -From 'monitor@example.com' -Subject 'Job Progress' `
    -SMTPServer 'smtp.office365.com'

Invoke-JSMProcessingLoop -JobDefinition $jobs -PeriodicReport -PeriodicReportSetting $settings
```

### Log File

```powershell
$settings = Set-JSMPeriodicReportSetting -Units Minutes -Length 5 -LogFilePath 'C:\Logs\jobs.csv'
```

### Status Log

```powershell
Get-JSMProcessingStatusEntry
Get-JSMProcessingStatusEntry -JobName 'GetData'
```

## JobType Selection

`Invoke-JSMProcessingLoop` auto-detects whether to use `Start-ThreadJob` or `Start-Job`:

- If `Start-ThreadJob` is available (PS 7+ or ThreadJob module installed): defaults to `ThreadJob`
- Otherwise: defaults to `PSJob`

Override explicitly:

```powershell
Invoke-JSMProcessingLoop -JobDefinition $jobs -JobType PSJob
Invoke-JSMProcessingLoop -JobDefinition $jobs -JobType ThreadJob
```

## Migration Guide (from v0.x / PoshRSJob)

### Rename `StartRSJobParams` to `StartJobParams`

```powershell
# Before (v0.x)
StartRSJobParams = @{ ScriptBlock = { ... } }

# After (v1.0)
StartJobParams = @{ ScriptBlock = { ... } }
```

### Remove `PSSnapinsToImport`

PS snap-ins are not supported on PS 7. Use `ModulesToImport` instead.

### Remove decoy argument workaround

PoshRSJob required a decoy first argument due to a bug. Native jobs do not. Remove the decoy argument from `ArgumentList` and its `param()` reference from your script blocks.

### Remove `Import-Module PoshRSJob`

No longer needed.

## Contributing

Code style follows the [PoshCode PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style).

Run tests before submitting:

```powershell
Invoke-Pester -Path ./Tests -Output Detailed
```
