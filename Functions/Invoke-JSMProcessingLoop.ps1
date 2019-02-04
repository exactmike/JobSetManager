function Invoke-JSMProcessingLoop
{
    [cmdletbinding()]
    param
    (
        [parameter()]
        [Alias('Settings')]
        $Conditions
        ,
        # The Job Definitions for the Job Set you want to invoke
        [Parameter(Mandatory)]
        [psobject[]]$JobDefinitions
        ,
        [parameter()]
        [ValidateRange(5,60)]
        [int16]$SleepSecondsBetweenJobCheck = 20
        ,
        [switch]$Interactive
        ,
        [switch]$RetainFailedJobs
        ,
        [switch]$RestartStopwatch
        ,
        [switch]$LoopOnce
        ,
        [int]$JobFailureRetryLimit = 3
        ,
        [switch]$PeriodicReport
        ,
        $PeriodicReportSettings
        ,
        [switch]$IgnoreFatalFailure
        ,
        [switch]$SuppressVariableRemoval
    )
    ##################################################################
    #Get the Required Jobs from the JobDefinitions
    ##################################################################
    try
    {
        $message = 'Invoke-JobProcessingLoop: Get-RequiredJob'
        Write-Verbose -Message $message
        $GRJParams = @{
            JobDefinition = $JobDefinitions
            ErrorAction = 'Stop'
        }
        if ($PSBoundParameters.ContainsKey('Conditions'))
        {
            $GRJParams.Conditions = $Conditions
        }
        $RequiredJobs = Get-JSMRequiredJob @GRJParams
        $RequiredJobsLookup = @{}
        foreach ($j in $RequiredJobs) {$RequiredJobsLookup.$($j.name) = $true}
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
    Start-JSMStopwatch
    ##################################################################
    #Loop to manage Jobs to successful completion or gracefully handled failure
    ##################################################################
    $StopLoop = $false
    $FatalFailure = $false
    Do
    {
        #Get Completed and Current Jobs
        $CompletedJobs = Get-JSMCompletedJob
        $FailedJobs = Get-JSMFailedJob
        $CurrentJobs = Get-JSMCurrentJob -RequiredJob $RequiredJobs -CompletedJob $CompletedJobs
        #Check for jobs that meet their start criteria
        $JobsToStart = @(Get-JSMNextJob -CompletedJob $CompletedJobs -CurrentJob $CurrentJobs -RequiredJob $RequiredJobs -FailedJob $FailedJobs -JobFailureRetryLimit $JobFailureRetryLimit)
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs To Start. Submitting to Start-JSMJob."
            Write-Verbose -message $message
            $FailedStartJobs = @(Start-JSMJob -Job $JobsToStart)
        }#if
        #Check for newly completed jobs that may need to be received and validated and for newly failed jobs for fail processing
        $SNCJPParams = @{
            CompletedJob = $CompletedJobs
            RequiredJob = $RequiredJobs
        }
        if ($true -eq $SuppressVariableRemoval) {$SNCJPParams.SuppressVariableRemoval = $true}
        $NewlyFailedJobs = Start-JSMNewlyCompletedJobProcess @SNCJPParams
        if ($null -ne $FailedStartJobs -and $FailedStartJobs.count -ge 1)
        {
            $NewlyFailedJobs += $FailedStartJobs
        }
        #move NewlyFailed handling out to discrete function soon - 20190127
        if ($NewlyFailedJobs.count -ge 1)
        {
            $message = "Found $($NewlyFailedJobs.Count) Newly Failed Jobs. Submitting to Start-JSMFailedJobProcess."
            Write-Verbose -message $message
            $FatalFailure = Start-JSMFailedJobProcess -NewlyFailedJobs $NewlyFailedJobs
        }
        $CompletedJobs = Get-JSMCompletedJob
        $CurrentJobs = Get-JSMCurrentJob -CompletedJob $CompletedJobs -RequiredJob $RequiredJobs
        $FailedJobs = Get-JSMFailedJob
        $PendingJobs = Get-JSMPendingJob -RequiredJob $RequiredJobs
        if ($true -eq $Interactive)
        {
            $originalVerbosePreference = $VerbosePreference
            $VerbosePreference = 'Continue'
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "$(Get-Date)"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Pending Jobs: $(($PendingJobs.Keys | sort-object) -join ',')"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Currently Running Jobs: $(($CurrentJobs.Keys | sort-object) -join ',')"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Completed Jobs: $(($CompletedJobs.Keys | sort-object) -join ',' )"
            Write-Verbose -Message "=========================================================================="
            if ($FailedJobs.Keys.Count -ge 1)
            {
                Write-Verbose -Message "Jobs With Failed Attempts: $(($Script:FailedJobs.Keys | sort-object) -join ',' )"
                Write-Verbose -Message "=========================================================================="
            }
            if ($true -eq $FatalFailure)
            {
                Write-Verbose -Message "A Fatal Job Failure Has Occurred"
                Write-Verbose -Message "=========================================================================="
            }
            $VerbosePreference = $originalVerbosePreference
        }
        if ($true -eq $PeriodicReport)
        {
            Start-JSMPeriodicReportProcess -PeriodicReportSettings $PeriodicReportSettings -RequiredJob $RequiredJobs -stopwatch $Script:Stopwatch -CompletedJob $CompletedJobs -FailedJob $FailedJobs -CurrentJob $CurrentJobs
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
        {
            if ($Interactive) {$VerbosePreference = 'Continue'}
            Write-Verbose -message "Safe to interrupt loop for next $SleepSecondsBetweenJobCheck seconds"
            Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
            if ($Interactive) {$VerbosePreference = $originalVerbosePreference}
        }
    }
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($CompletedJobs.Keys) -ReferenceObject @($RequiredJobs.Name))) -or $StopLoop)
    $(-not $FatalFailure)
}
