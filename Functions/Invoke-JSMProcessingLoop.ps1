function Invoke-JSMProcessingLoop
{
    [cmdletbinding()]
    param
    (
        $Settings
        ,
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
    )
    ##################################################################
    #Get the Required Jobs from the JobDefinitions
    ##################################################################
    try
    {
        $message = 'Invoke-JobProcessingLoop: Get-RequiredJob'
        Write-Verbose -Message $message
        $RequiredJobs = Get-JSMRequiredJob -Settings $Settings -JobDefinitions $jobDefinitions -ErrorAction Stop
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
    $CompletedJobs = Get-JSMCompletedJob
    $FailedJobs = Get-JSMFailedJob
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
        $CurrentJobs = Get-JSMCurrentJob -RequiredJob $RequiredJobs -CompletedJob $CompletedJobs
        $FailedJobs = Get-JSMFailedJob
        #Check for jobs that meet their start criteria
        $JobsToStart = @(Get-JSMNextJob -CompletedJob $CompletedJobs -CurrentJob $CurrentJobs -RequiredJob $RequiredJobs -FailedJob $FailedJobs -JobFailureRetryLimit $JobFailureRetryLimit)
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs To Start. Submitting to Start-JSMJob."
            Write-Verbose -message $message
            $FailedStartJobs = Start-JSMJob -Job $JobsToStart
        }#if
        #Check for newly completed jobs that may need to be received and validated and for newly failed jobs for fail processing
        $NewlyFailedJobs = Start-JSMNewlyCompletedJobProcess -CompletedJob $CompletedJobs -RequiredJob $RequiredJobs
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
        if ($true -eq $Interactive)
        {
            $originalVerbosePreference = $VerbosePreference
            $VerbosePreference = 'Continue'
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "$(Get-Date)"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Currently Running Jobs: $(($CurrentJobs.Keys | sort-object) -join ',')"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Newly Completed Jobs: $(($NewlyCompletedJobs.Keys | sort-object) -join ',' )"
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
            Write-Verbose -message "Safe to interrupt loop for next $SleepSecondsBetweenJobCheck seconds"
            Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
        }
    }
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($CompletedJobs.Keys) -ReferenceObject @($RequiredJobs.Name))) -or $StopLoop)
    $(-not $FatalFailure)
}
