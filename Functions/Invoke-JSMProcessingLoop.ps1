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
    # Auto-detect JobType if not specified
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
    #Get the Required Jobs from the JobDefinitions
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
    #Prep for Jobs Loop
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
    #Loop to manage Jobs to successful completion or gracefully handled failure
    ##################################################################
    $StopLoop = $false
    $FatalFailure = $false
    Do
    {
        #Get Completed and Current Jobs
        $JobCompletions = Get-JSMJobCompletion
        $JobFailures = Get-JSMJobFailure
        $JobCurrent = Get-JSMJobCurrent -JobRequired $JobRequired -JobCompletion $JobCompletions
        #Detect stale job attempts (tracked as active but not found in the job engine)
        $ActiveAttempts = @(Get-JSMJobAttempt -Active $true -StopType 'None')
        $NativeJobNames = @(Get-Job).Name
        $StaleJobFailures = @()
        foreach ($attempt in $ActiveAttempts)
        {
            $jobName = $attempt.JobName
            if ($jobName -in $JobCompletions.Keys -or $jobName -in $JobCurrent.Keys) { continue }
            $isStale = $true
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
                $staleJobDef = $JobRequired | Where-Object { $_.Name -eq $jobName } | Select-Object -First 1
                if ($null -ne $staleJobDef)
                {
                    Add-JSMJobFailure -Name $jobName -FailureType 'StaleJob' -Attempt $attempt
                    $StaleJobFailures += $staleJobDef | Select-Object -Property *,@{n='FailureType';e={'StaleJob'}}
                }
            }
        }
        #Check for jobs that meet their start criteria
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
        #Check for newly completed jobs that may need to be received and validated and for newly failed jobs for fail processing
        $SNCJPParams = @{
            JobCompletion = $JobCompletions
            JobRequired = $JobRequired
        }
        $NewJobFailures = $null
        if ($true -eq $SuppressVariableRemoval) {$SNCJPParams.SuppressVariableRemoval = $true}
        $NewJobFailures = @(Start-JSMNewJobCompletionProcess @SNCJPParams)
        if ($null -ne $StartJobFailures -and $StartJobFailures.count -ge 1)
        {
            $NewJobFailures += $StartJobFailures
        }
        if ($StaleJobFailures.Count -ge 1)
        {
            $NewJobFailures += $StaleJobFailures
        }
        #move NewlyFailed handling out to discrete function soon - 20190127
        if ($NewJobFailures.count -ge 1)
        {
            $message = "Found $($NewJobFailures.Count) New Job Failure(s). Submitting to Start-JSMJobFailureProcess."
            Write-Verbose -message $message
            $FatalFailure = Start-JSMJobFailureProcess -NewJobFailure $NewJobFailures -JobFailureRetryLimit $JobFailureRetryLimit
        }
        $JobCurrent = Get-JSMJobCurrent -JobCompletion $JobCompletions -JobRequired $JobRequired
        $JobPending = Get-JSMJobPending -JobRequired $JobRequired
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
        {   #add a check here for situation all jobs completed and skip if so
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
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($JobCompletions.Keys) -ReferenceObject @($JobRequired.Name))) -or $StopLoop)
    $(-not $FatalFailure)
}
