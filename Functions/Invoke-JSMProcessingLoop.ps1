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
    $JobProcessingLoopFailure = $false
    $StopLoop = $false
    Do
    {
        $newlyCompletedJobs = @()
        $newlyFailedDefinedJobs = @()
        #Get Completed and Current Jobs
        $CompletedJobs = Get-JSMCompletedJob
        $CurrentJobs = Get-JSMCurrentJob -RequiredJob $RequiredJobs -CompletedJob $CompletedJobs
        #Check for jobs that meet their start criteria
        $JobsToStart = @(Get-JSMNextJob -CompletedJobs $CompletedJobs -CurrentJobs $CurrentJobs -RequiredJobs $RequiredJobs)
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs To Start. Submitting to Start-JSMJob."
            Write-Verbose -message $message
            $FailedStartJobs = Start-JSMJob -Job $JobsToStart
        }#if
        #Check for newly completed jobs that may need to be received and validated and for newly failed jobs for fail processing
        $NewlyCompletedJobs,$NewlyFailedJobs = Start-JSMNewlyCompletedJobProcess -CompletedJob $CompletedJobs -RequiredJob $RequiredJobs
        if ($null -ne $FailedStartJobs -and $FailedStartJobs.count -ge 1)
        {
            $NewlyFailedJobs += $FailedStartJobs
        }
        #move NewlyFailed handling out to discrete function soon - 20190127
        if ($NewlyFailedJobs.count -ge 1)
        {
            foreach ($j in $newlyFailedJobs)
            {
                Add-JSMFailedJob -Name $j.Name -FailureType $j.FailureType
                $FailedJobs = Get-JSMFailedJob
                #if JobFailureRetryLimit exceeded then abort the loop
                $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
                if ($FailedJobs.$($j.name).FailureCount -ge $JobFailureRetryLimitForThisJob)
                {
                    $message = "$($j.Name): Exceeded JobFailureRetry Limit. Ending Job Processing Loop. Failure Count: $($FailedJobs.$($j.name).FailureCount). FailureTypes: $($FailedJobs.$($j.name).FailureType -join ',')"
                    Write-Warning -Message $message
                    Update-JSMProcessingLoopStatus -Job $j.name -Message $message -Status $false
                    $JobProcessingLoopFailure = $true
                    $StopLoop = $true
                }
                else #otherwise remove the jobs and we'll try again next loop
                {
                    try
                    {
                        $message = "$($j.Name): Removing Failed RSJob(s)."
                        Write-Verbose -Message $message
                        Get-RSJob -Name $j.name | Remove-RSJob -ErrorAction Stop
                        Write-Verbose -Message $message
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                    }
                }
            }
        }
        $CompletedJobs = Get-JSMCompletedJob
        $CurrentJobs = Get-JSMCurrentJob -CompletedJob $CompletedJobs -RequiredJob $RequiredJobs
        $FailedJobs = Get-JSMFailedJob
        if ($true -eq $Interactive -or $true -eq $PeriodicReport)
        {
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "$(Get-Date)" -Verbose
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
        }
        if ($true -eq $PeriodicReport)
        {
            Start-JSMPeriodicReportProcess -PeriodicReportSettings $PeriodicReportSettings -RequiredJob $RequiredJobs -stopwatch $Script:Stopwatch -CompletedJob $CompletedJobs -FailedJob $FailedJobs -CurrentJob $CurrentJobs
        }
        if ($LoopOnce -eq $true)
        {
            $StopLoop = $true
        }
        else
        {
            Write-Verbose -message "Safe to interrupt loop for next $SleepSecondsBetweenJobCheck seconds"
            Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
        }
    }
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($CompletedJobs.Keys) -ReferenceObject @($RequiredJobs.Name))) -or $StopLoop)
    if ($JobProcessingLoopFailure)
    {
        $False
    }
    else
    {
        $true
    }
}
