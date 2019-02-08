function Invoke-JSMProcessingLoop
{
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
        [switch]$RetainJobFailures
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
    )
    ##################################################################
    #Get the Required Jobs from the JobDefinitions
    ##################################################################
    try
    {
        $message = 'Invoke-JobProcessingLoop: Get-RequiredJob'
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
    Start-JSMStopwatch
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
        #Check for jobs that meet their start criteria
        $JobsToStart = @(Get-JSMJobNext -JobCompletion $JobCompletions -JobCurrent $JobCurrent -JobRequired $JobRequired -JobFailure $JobFailures -JobFailureRetryLimit $JobFailureRetryLimit)
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs To Start. Submitting to Start-JSMJob."
            Write-Verbose -message $message
            $StartJobFailures = @(Start-JSMJob -Job $JobsToStart)
        }#if
        #Check for newly completed jobs that may need to be received and validated and for newly failed jobs for fail processing
        $SNCJPParams = @{
            JobCompletion = $JobCompletions
            JobRequired = $JobRequired
        }
        if ($true -eq $SuppressVariableRemoval) {$SNCJPParams.SuppressVariableRemoval = $true}
        $NewJobFailures = Start-JSMNewJobCompletionProcess @SNCJPParams
        if ($null -ne $StartJobFailures -and $StartJobFailures.count -ge 1)
        {
            $NewJobFailures += $StartJobFailures
        }
        #move NewlyFailed handling out to discrete function soon - 20190127
        if ($NewJobFailures.count -ge 1)
        {
            $message = "Found $($NewJobFailures.Count) New Job Failure(s). Submitting to Start-JSMJobFailureProcess."
            Write-Verbose -message $message
            $FatalFailure = Start-JSMJobFailureProcess -NewJobFailure $NewJobFailures
        }
        $JobCompletions = Get-JSMJobCompletion
        $JobCurrent = Get-JSMJobCurrent -JobCompletion $JobCompletions -JobRequired $JobRequired
        $JobFailures = Get-JSMJobFailure
        $JobPending = Get-JSMJobPending -JobRequired $JobRequired
        if ($true -eq $Interactive)
        {
            $originalVerbosePreference = $VerbosePreference
            $VerbosePreference = 'Continue'
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "$(Get-Date)"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Pending Jobs: $(($JobPending.Keys | sort-object) -join ',')"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Currently Running Jobs: $(($JobCurrent.Keys | sort-object) -join ',')"
            Write-Verbose -Message "=========================================================================="
            Write-Verbose -Message "Completed Jobs: $(($JobCompletions.Keys | sort-object) -join ',' )"
            Write-Verbose -Message "=========================================================================="
            if ($JobFailures.Keys.Count -ge 1)
            {
                Write-Verbose -Message "Jobs With Failed Attempts: $(($Script:JobFailures.Keys | sort-object) -join ',' )"
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
            Start-JSMPeriodicReportProcess -PeriodicReportSetting $PeriodicReportSetting -JobRequired $JobRequired -stopwatch $Script:Stopwatch -JobCompletion $JobCompletions -JobFailure $JobFailures -JobCurrent $JobCurrent
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
            #if ($JobCurrent.count -eq 0 -and $JobPending.count -eq 0)
            [gc]::Collect()
            [gc]::WaitForPendingFinalizers()
            [gc]::Collect()
            if ($Interactive) {$VerbosePreference = 'Continue'}
            Write-Verbose -message "Safe to interrupt loop for next $SleepSecondsBetweenJobCheck seconds"
            Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
            if ($Interactive) {$VerbosePreference = $originalVerbosePreference}
        }
    }
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($JobCompletions.Keys) -ReferenceObject @($JobRequired.Name))) -or $StopLoop)
    $(-not $FatalFailure)
}
