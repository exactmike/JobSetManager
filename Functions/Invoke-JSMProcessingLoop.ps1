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
            $message = "Found $($JobsToStart.Count) Jobs Ready To Start"
            Write-Verbose -message $message
            foreach ($job in $jobsToStart)
            {
                $message = "$($job.Name): Ready to Start"
                Write-Verbose -message $message
                Update-JSMProcessingLoopStatus -Job $Job.name -Message $message -Status $true
            }
            #Start the jobs
            :nextJobToStart foreach ($job in $JobsToStart)
            {
                #Run the PreJobCommands
                if ([string]::IsNullOrWhiteSpace($job.PreJobCommands) -eq $false)
                {
                    $message = "$($job.Name): Found PreJobCommands."
                    Write-Verbose -Message $message
                    $message = "$($job.Name): Run PreJobCommands"
                    try
                    {
                        Write-Verbose -Message $message
                        . $($job.PreJobCommands)
                        Write-Verbose -Message $message
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        continue nextJobToStart
                        $newlyFailedDefinedJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'PreJobCommands'}})
                    }
                }
                #Prepare the Start-RSJob Parameters
                $StartRSJobParams = $job.StartRSJobParams
                $StartRSJobParams.Name = $job.Name
                #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartRSJobParameters property)
                if ($job.ArgumentList.count -ge 1)
                {
                    $message = "$($job.Name): Found ArgumentList to populate with live variables."
                    Write-Verbose -Message $message
                    try
                    {
                        $StartRSJobParams.ArgumentList = @(
                            foreach ($a in $job.ArgumentList)
                            {
                                $message = "$($job.Name): Get Argument List Variable $a"
                                Write-Verbose -Message $message
                                Get-Variable -Name $a -ValueOnly -ErrorAction Stop
                                Write-Verbose -Message $message
                            }
                        )
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        continue nextJobToStart
                    }
                }
                #if the job definition calls for splitting the workload among multiple jobs
                if ($job.JobSplit -gt 1)
                {
                    $StartRSJobParams.Throttle = $job.JobSplit
                    $StartRSJobParams.Batch = $job.Name
                    try
                    {
                        $message = "$($job.Name): Get the data to split from variable $($job.jobsplitDataVariableName)"
                        Write-Verbose -Message $message
                        $DataToSplit = Get-Variable -Name $job.JobSplitDataVariableName -ValueOnly -ErrorAction Stop
                        Write-Verbose -Message $message
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        continue nextJobToStart
                    }
                    try
                    {
                        $message = "$($job.Name): Calculate the split ranges for the data $($job.jobsplitDataVariableName) for $($job.JobSplit) batch jobs"
                        Write-Verbose -Message $message
                        $splitGroups = New-SplitArrayRange -inputArray $DataToSplit -parts $job.JobSplit -ErrorAction Stop
                        Write-Verbose -Message $message
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        continue nextJobToStart
                    }
                    $splitjobcount = 0
                    foreach ($split in $splitGroups)
                    {
                        $splitjobcount++
                        $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                        try
                        {
                            $message = "$($job.Name): Start Batch Job $splitjobcount of $($job.JobSplit)"
                            Write-Verbose -Message $message
                            Start-RSJob @StartRSJobParams | Out-Null
                            Write-Verbose -Message $message
                            Update-JSMProcessingLoopStatus -Job $Job.name -Message $message -Status $true
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            Update-JSMProcessingLoopStatus -Job $Job.name -Message $message -Status $false
                            continue nextJobToStart
                        }
                    }
                }
                #otherwise just start one job
                else
                {
                    try
                    {
                        $message = "$($job.Name): Start Job"
                        Write-Verbose -Message $message
                        Start-RSJob @StartRSJobParams | Out-Null
                        Write-Verbose -Message $message
                        Update-JSMProcessingLoopStatus -Job $Job.name -Message $message -Status $true
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        Update-JSMProcessingLoopStatus -Job $Job.name -Message $message -Status $false
                        continue nextJobToStart
                    }
                }
                $job | Add-Member -MemberType NoteProperty -Name StartTime -Value (Get-Date) -Force
            }
            $message = "Finished Processing Jobs Ready To Start"
            Write-Verbose -message $message
        }#if
        #Check for newly completed jobs that may need to be received and validated
        $NewlyCompletedJobs,$NewlyFailedJobs = Process-JSMNewlyCompletedJob -CompletedJob $CompletedJobs -RequiredJob $RequiredJobs
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
            Process-JSMPeriodicReport -PeriodicReportSettings $PeriodicReportSettings -RequiredJob $RequiredJobs -stopwatch $Script:Stopwatch -CompletedJob $CompletedJobs -FailedJob $FailedJobs -CurrentJob $CurrentJobs
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
