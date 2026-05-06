function Invoke-JSMProcessingLoop
{
    <#
    .SYNOPSIS
        Runs the main job orchestration loop for a set of interdependent jobs.
    .DESCRIPTION
        Manages the full lifecycle of a job set: resolves dependencies, starts eligible jobs,
        receives and validates completed jobs, handles failures with retry logic, and loops
        until all jobs complete or a fatal failure occurs. Supports both Start-Job (PSJob) and
        Start-ThreadJob (ThreadJob) engines with auto-detection.
    .PARAMETER Condition
        A hashtable of condition name/value pairs used to filter job definitions via OnCondition
        and OnNotCondition. Aliased as 'Settings' for backward compatibility.
    .PARAMETER JobDefinition
        The array of job definition objects that make up the job set.
    .PARAMETER SleepSecondsBetweenJobCheck
        Seconds to sleep between loop iterations. Valid range: 5-60. Default: 20.
    .PARAMETER Interactive
        When specified, prints verbose progress output each loop iteration.
    .PARAMETER RestartStopwatch
        When specified, restarts the internal stopwatch even if it is already running.
    .PARAMETER LoopOnce
        When specified, runs only one iteration of the loop and exits.
    .PARAMETER JobFailureRetryLimit
        Global maximum number of retry attempts per job. Default: 3.
    .PARAMETER PeriodicReport
        When specified, calls Start-JSMPeriodicReportProcess each iteration.
    .PARAMETER PeriodicReportSetting
        Settings object created by Set-JSMPeriodicReportSetting.
    .PARAMETER IgnoreFatalFailure
        When specified, continues looping even after a fatal failure is detected.
    .PARAMETER SuppressVariableRemoval
        When specified, skips removal of variables listed in job RemoveVariablesAtCompletion.
    .PARAMETER JobType
        Job engine: PSJob (Start-Job) or ThreadJob (Start-ThreadJob). Auto-detected if not specified.
    .EXAMPLE
        PS C:\> Invoke-JSMProcessingLoop -JobDefinition $jobs -Interactive

        Runs the job set with verbose interactive output. Auto-detects job engine.
    .EXAMPLE
        PS C:\> Invoke-JSMProcessingLoop -JobDefinition $jobs -JobType PSJob -JobFailureRetryLimit 5

        Runs with Start-Job and allows up to 5 retries per job.
    .OUTPUTS
        [bool] $true if all jobs completed without fatal failure, $false otherwise.
    #>
    [cmdletbinding()]
    param
    (
        [parameter()]
        [Alias('Settings')]
        $Condition
        ,
        # The Job Definitions for the Job Set you want to invoke
        [Parameter(Mandatory)]
        [psobject[]]$JobDefinition
        ,
        [parameter()]
        [ValidateRange(5,60)]
        [int16]$SleepSecondsBetweenJobCheck = 20
        ,
        [switch]$Interactive
        ,
        [switch]$RestartStopwatch
        ,
        [switch]$LoopOnce
        ,
        [int]$JobFailureRetryLimit = 3
        ,
        [switch]$PeriodicReport
        ,
        $PeriodicReportSetting
        ,
        [switch]$IgnoreFatalFailure
        ,
        [switch]$SuppressVariableRemoval
        ,
        # Job engine type. Defaults to ThreadJob if Start-ThreadJob is available, otherwise PSJob.
        [ValidateSet('PSJob','ThreadJob')]
        [string]$JobType
    )
    # Auto-detect JobType if not specified: prefer ThreadJob (lower overhead) when available,
    # fall back to PSJob (Start-Job) which is always present.
    if (-not $PSBoundParameters.ContainsKey('JobType'))
    {
        if ($null -ne (Get-Command 'Start-ThreadJob' -ErrorAction SilentlyContinue))
        {
            $JobType = 'ThreadJob'
        }
        else
        {
            $JobType = 'PSJob'
        }
        Write-Verbose -Message "Invoke-JSMProcessingLoop: Auto-detected JobType: $JobType"
    }
    ##################################################################
    # Phase 1 — Pre-loop: resolve the required job set
    # Filter the full JobDefinition array down to the jobs that should
    # actually run, honoring OnCondition / OnNotCondition gates.
    # Returns a hashtable keyed by job name for O(1) lookups downstream.
    # Returns $null (fatal) if no jobs pass the condition filter.
    ##################################################################
    try
    {
        $message = 'Invoke-JSMProcessingLoop: Get-JSMJobRequired'
        Write-Verbose -Message $message
        $GRJParams = @{
            JobDefinition = $JobDefinition
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Condition'))
        {
            $GRJParams.Condition = $Condition
        }
        $JobRequired = Get-JSMJobRequired @GRJParams
        Write-Verbose -Message $message
    }
    catch
    {
        $myerror = $_.tostring()
        Write-Warning -Message $message
        Write-Warning -Message $myerror
        Return $null
    }
    ##################################################################
    # Phase 2 — Pre-loop: initialize state
    # Start (or restart) the module stopwatch used by periodic reporting.
    # Initialize all script-scope tracking variables (idempotent — safe
    # to call even if a prior run left state behind).
    ##################################################################
    if ($RestartStopwatch)
    {
        Start-JSMStopwatch -Restart
    }
    else
    {
        Start-JSMStopwatch
    }
    Initialize-TrackingVariable
    ##################################################################
    # Phase 3 — Main orchestration loop
    # Runs until all required jobs complete (Until condition) or
    # $StopLoop is set (LoopOnce, fatal failure, or IgnoreFatalFailure).
    # Each iteration follows a fixed sequence:
    #   a) Snapshot current state
    #   b) Detect stale (orphaned) job attempts
    #   c) Start newly eligible jobs
    #   d) Process newly completed jobs
    #   e) Aggregate and route failures
    #   f) Refresh current/pending counts
    #   g) Report / sleep
    #   h) Evaluate loop-exit conditions
    ##################################################################
    $StopLoop = $false
    $FatalFailure = $false
    Do
    {
        # (a) Snapshot: capture completed jobs, failures, and running jobs at the
        # top of this iteration. All downstream steps in this iteration use this
        # consistent snapshot rather than re-querying state mid-loop.
        $JobCompletions = Get-JSMJobCompletion
        $JobFailures = Get-JSMJobFailure
        $JobCurrent = Get-JSMJobCurrent -JobRequired $JobRequired -JobCompletion $JobCompletions

        # (b) Stale job detection: find attempts recorded as active in $script:JobAttempts
        # that are no longer present in the native job engine (Get-Job). This catches
        # jobs that were silently removed outside of JSM (e.g. session cleanup, manual
        # removal). Stale jobs are marked as failed so retry / fatal logic applies.
        $ActiveAttempts = @(Get-JSMJobAttempt -Active $true -StopType 'None')
        $NativeJobNames = @(Get-Job).Name
        $StaleJobFailures = [System.Collections.Generic.List[psobject]]::new()
        foreach ($attempt in $ActiveAttempts)
        {
            $jobName = $attempt.JobName
            # Skip if already resolved in this iteration's snapshot
            if ($jobName -in $JobCompletions.Keys -or $jobName -in $JobCurrent.Keys) { continue }
            $isStale = $true
            # For split jobs, the parent name won't appear in Get-Job; check sub-job names
            if ($null -ne $script:SplitJobGroups -and $script:SplitJobGroups.ContainsKey($jobName))
            {
                $subNames = $script:SplitJobGroups[$jobName]
                if ($NativeJobNames | Where-Object { $_ -in $subNames }) { $isStale = $false }
            }
            if ($isStale)
            {
                $staleMessage = "$jobName : Active job attempt found but job is missing from the job engine. Flagging as stale failure."
                Write-Warning -Message $staleMessage
                Add-JSMProcessingStatusEntry -Job $jobName -Message $staleMessage -Status $false -EventID 520
                Set-JSMJobAttempt -Attempt $attempt.Attempt -JobName $jobName -StopType Fail
                $staleJobDef = $JobRequired[$jobName]
                if ($null -ne $staleJobDef)
                {
                    Add-JSMJobFailure -Name $jobName -FailureType 'StaleJob' -Attempt $attempt
                    $StaleJobFailures.add($($staleJobDef | Select-Object -Property *,@{n='FailureType';e={'StaleJob'}}))
                }
            }
        }

        # (c) Start eligible jobs: Get-JSMJobNext evaluates each required job against
        # completion, running, failure, and dependency state. Jobs whose DependsOnJobs
        # are all completed and whose retry count is below the limit are returned.
        # Start-JSMJob handles PreJobCommands, ArgumentList resolution, InitializationScript
        # assembly, and split-job sub-job creation.
        $JobsToStart = @(Get-JSMJobNext -JobCompletion $JobCompletions -JobCurrent $JobCurrent -JobRequired $JobRequired -JobFailure $JobFailures -JobFailureRetryLimit $JobFailureRetryLimit)
        $StartJobSuccesses,$StartJobFailures  = $null
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs To Start. Submitting to Start-JSMJob."
            Write-Verbose -message $message
            $StartResult = Start-JSMJob -Job $JobsToStart -JobType $JobType
            $StartJobSuccesses = $StartResult.SuccessStartJobs
            $StartJobFailures = $StartResult.FailedStartJobs
        }#end if
        if ($null -eq $StartJobSuccesses)
        {$StartJobSuccesses = @()}

        # (d) Completion processing: scan for jobs in 'Completed' state that have not
        # yet been recorded. For each: receive output, validate against ResultsValidation,
        # assign to configured global variables, run PostJobCommands, remove the native
        # job, and clean up RemoveVariablesAtCompletion. Returns failure objects for any
        # job that fails validation or variable assignment.
        $SNCJPParams = @{
            JobCompletion = $JobCompletions
            JobRequired = $JobRequired
        }
        if ($true -eq $SuppressVariableRemoval) {$SNCJPParams.SuppressVariableRemoval = $true}
        $CompletionFailures = @(Start-JSMNewJobCompletionProcess @SNCJPParams)

        # (e) Failure aggregation and routing: collect failure objects from all three
        # sources (completion failures, start failures, stale failures) and pass to
        # Start-JSMJobFailureProcess which decides retry vs. fatal for each.
        # Returns $true if any failure exceeded the retry limit.
        $FatalFailure = Start-JSMNewJobFailureProcess `
            -CompletionFailures $CompletionFailures `
            -StartJobFailures $StartJobFailures `
            -StaleJobFailures $StaleJobFailures `
            -JobFailureRetryLimit $JobFailureRetryLimit

        # (f) Refresh current/pending counts post-completion so that reporting and the
        # loop-exit check reflect the state after this iteration's work.
        # Note: $JobCompletions is NOT refreshed here; the Until condition below still
        # uses the snapshot from step (a), so one extra iteration may occur after the
        # final job completes.
        $JobCurrent = Get-JSMJobCurrent -JobCompletion $JobCompletions -JobRequired $JobRequired
        $JobPending = Get-JSMJobPending -JobRequired $JobRequired

        # (g) Reporting: emit interactive verbose status and/or send periodic email report
        # when PeriodicReport or Interactive are active.
        if ($true -eq $PeriodicReport -or $true -eq $Interactive)
        {
            $startJSMPeriodicReportProcessSplat = @{
                PeriodicReportSetting = $PeriodicReportSetting
                JobRequired = $JobRequired
                Stopwatch = $Script:Stopwatch
                StartJobSuccess = $StartJobSuccesses
                JobFailure = $JobFailures
                Interactive = $Interactive
                JobCompletion = $JobCompletions
                FatalFailure = $FatalFailure
                JobCurrent = $JobCurrent
                JobPending = $JobPending
            }
            Start-JSMPeriodicReportProcess @startJSMPeriodicReportProcessSplat
        }

        # (h) Loop-exit evaluation — checked in priority order:
        #   1. LoopOnce: unconditionally stop after one iteration (testing/debugging).
        #   2. FatalFailure: stop unless IgnoreFatalFailure is set.
        #   3. All done: skip sleep when nothing is running or pending.
        #   4. Normal: sleep then continue.
        if ($LoopOnce -eq $true)
        {
            $StopLoop = $true
        }
        elseif ($true -eq $FatalFailure)
        {
            if ($true -ne $IgnoreFatalFailure)
            {
                $stopLoop = $true
            }
        }
        else
        {   # check here for situation all jobs completed and skip the interactive and sleep if so
            if ($JobCurrent.count -eq 0 -and $JobPending.count -eq 0)
            {
                Write-Verbose -message "Job Processing Complete"
            }
            else {
                [gc]::Collect()
                if ($Interactive) {$VerbosePreference = 'Continue'}
                Write-Verbose -message "Safe to interrupt Job Processing for the next $SleepSecondsBetweenJobCheck seconds"
                Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
                if ($Interactive) {$VerbosePreference = $originalVerbosePreference}
            }
        }
    }
    # Loop exits when every required job name appears in the completion snapshot
    # (Compare-Object returns $null when the two sets are identical) or when
    # $StopLoop has been set by LoopOnce or a fatal failure.
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($JobCompletions.Keys) -ReferenceObject @($JobRequired.Keys))) -or $StopLoop)
    # Return value: $true = all jobs completed without fatal failure; $false = fatal failure occurred.
    $(-not $FatalFailure)
}
