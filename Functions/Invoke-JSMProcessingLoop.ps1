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
        [switch]$FilterJobsOnly
        ,
        [switch]$RetainCompletedJobs
        ,
        [switch]$RetainFailedJobs
        ,
        [switch]$LoopOnce
        ,
        [switch]$ReportJobsToStartThenReturn
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
        $Global:RequiredJobs = Get-JSMRequiredJob -Settings $Settings -JobDefinitions $jobDefinitions -ErrorAction Stop
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
    if ($RetainCompletedJobs -eq $true -and ((Test-Path variable:Global:CompletedJobs) -eq $true))
    {
        #do nothing
    }
    else
    {
        $Global:CompletedJobs = @{} #Will add JobName as Key and Value as True when a job is completed
    }
    if ($RetainFailedJobs -eq $true -and ((Test-Path variable:Global:FailedJobs) -eq $true))
    {
        #do nothing
    }
    else
    {
        $Global:FailedJobs = @{} #Will add JobName as Key and value as array of failures that occured
    }
    ##################################################################
    #Loop to manage Jobs to successful completion or gracefully handled failure
    ##################################################################
    if ((Test-Path variable:Global:Stopwatch) -eq $false)
    {$Global:stopwatch = [system.diagnostics.stopwatch]::startNew()}
    Do
    {

        #initialize loop variables
        $newlyCompletedJobs = @()
        $newlyFailedDefinedJobs = @()
        #Get existing jobs and check for those that are running and/or newly completed
        $CurrentlyExistingRSJobs = @(Get-RSJob)
        $AllCurrentJobs = @($CurrentlyExistingRSJobs | Where-Object -FilterScript {$_.Name -notin $Global:CompletedJobs.Keys})
        $newlyCompletedRSJobs = @($AllCurrentJobs | Where-Object -FilterScript {$_.Completed -eq $true})
        #Check for jobs that meet their start criteria
        $jobsToStart = @(Get-JSMNextJob -CompletedJobs $Global:CompletedJobs -AllCurrentJobs $AllCurrentJobs -RequiredJobs $Global:RequiredJobs)
        if ($JobsToStart.Count -ge 1)
        {
            $message = "Found $($JobsToStart.Count) Jobs Ready To Start"
            Write-Verbose -message $message
            foreach ($job in $jobsToStart)
            {
                $message = "$($job.Name): Ready to Start"
                Write-Verbose -message $message
                Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $true
            }
            if ($ReportJobsToStartThenReturn -eq $true)
            {
                Return $null
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
                #if the job definition calls for splitting the workload among several jobs
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
                            Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $true
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
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
                        Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $true
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
                        continue nextJobToStart
                    }
                }
                switch (Test-Member -Name StartTime -MemberType NoteProperty -InputObject $job)
                {
                    $true
                    {$job.StartTime = Get-Date}
                    $false
                    {$job | Add-Member -MemberType NoteProperty -Name StartTime -Value (Get-Date)}
                }
            }
            $message = "Finished Processing Jobs Ready To Start"
            Write-Verbose -message $message
        }#if
        #Check for newly completed jobs that may need to be received and validated
        if ($newlyCompletedRSJobs.count -ge 1)
        {
            $skipBatchJobs = @{}
            $newlyCompletedJobs = @(
                :nextRSJob foreach ($rsJob in $newlyCompletedRSJobs)
                {
                    #skip examining this job if another in the same batch has already been examined in this loop
                    if ($skipBatchJobs.ContainsKey($rsJob.name))
                    {
                        continue nextRSJob
                    }
                    #Match the RS Job to the Job Definition
                    $DefinedJob = @($Global:RequiredJobs | Where-Object -FilterScript {$_.name -eq $rsJob.name})
                    if ($DefinedJob.Count -eq 1)
                    {
                        $DefinedJob = $DefinedJob[0]
                    }
                    else
                    {
                        #this is not a managed job so we move on to the next one
                        continue nextRSJob
                    }
                    #if the job is split into batched jobs, check if all batched jobs are completed
                    if ($DefinedJob.JobSplit -gt 1)
                    {
                        $BatchRSJobs = @(Get-RSJob -Batch $DefinedJob.Name)
                        if ($BatchRSJobs.Count -eq $DefinedJob.JobSplit)
                        {
                            if (($BatchRSJobs.Completed) -contains $false)
                            {
                                $skipBatchJobs.$($DefinedJob.Name) = $true
                                continue nextRSJob
                            }
                            else
                            {
                                $skipBatchJobs.$($DefinedJob.Name) = $true
                            }
                        }
                        else #this is a failure that needs to be raised
                        {
                            #how should we exit the loop and report what happened?
                            #$NewlyFailedJobs += $($BatchRSJobs | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'SplitJobCountMismatch')
                        }
                    }
                    switch (Test-Member -InputObject $DefinedJob -Name EndTime -MemberType NoteProperty)
                    {
                        $true
                        {$DefinedJob.EndTime = Get-Date}
                        $false
                        {$DefinedJob | Add-Member -MemberType NoteProperty -Name EndTime -Value (Get-Date)}
                    }
                    $DefinedJob
                }
            )
        }
        if ($newlyCompletedJobs.Count -ge 1)
        {
            Write-Verbose -Message "Found $($newlyCompletedJobs.Count) Newly Completed Defined Job(s) to Process: $($newlyCompletedJobs.Name -join ',')"
        }
        :nextDefinedJob foreach ($DefinedJob in $newlyCompletedJobs)
        {
            $ThisDefinedJobSuccessfullyCompleted = $false
            Write-Verbose -Message "$($DefinedJob.name): RS Job Newly completed"
            $message = "$($DefinedJob.name): Match newly completed RSJob to Defined Job."
            try
            {
                Write-Verbose -Message $message
                $RSJobs = @(Get-RSJob -Name $DefinedJob.Name -ErrorAction Stop)
                Write-Verbose -Message $message
            }
            catch
            {
                $myerror = $_
                Write-Warning -Message $message
                Write-Warning -Message $myerror.tostring()
                continue nextDefinedJob
            }
            if ($DefinedJob.JobSplit -gt 1 -and ($RSJobs.Count -eq $DefinedJob.JobSplit) -eq $false)
            {
                $message = "$($DefinedJob.name): RSJob Count does not match Defined Job SplitJob specification."
                Write-Warning -Message $message
                continue nextDefinedJob
            }
            #Log any Errors from the RS Job
            if ($RSJobs.HasErrors -contains $true)
            {
                $message = "$($DefinedJob.Name): reported errors"
                Write-Warning -Message $message
                $Errors = foreach ($rsJob in $RSJobs) {if ($rsJob.Error.count -gt 0) {$rsJob.Error.getenumerator()}}
                if ($Errors.count -gt 0)
                {
                    $ErrorStrings = $Errors | ForEach-Object -Process {$_.ToString()}
                    Write-Warning -Message $($($DefinedJob.Name + ' Errors: ') + $($ErrorStrings -join '|'))
                }
            }#if
            #Receive the RS Job Results to generic JobResults variable.
            try
            {
                $message = "$($DefinedJob.Name): Receive Results to Generic JobResults variable pending validation"
                Write-Verbose -Message $message
                $JobResults = Receive-RSJob -Job $RSJobs -ErrorAction Stop
                Write-Verbose -Message $message
                Update-JSMJobSetStatus -Job $DefinedJob.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $NewlyFailedDefinedJobs += $($DefinedJob | Select-Object -Property *,@{n='FailureType';e={'ReceiveRSJob'}})
                Update-JSMJobSetStatus -Job $DefinedJob.name -Message $message -Status $false
                Continue nextDefinedJob
            }
            #Validate the JobResultsVariable
            if ($DefinedJob.ResultsValidation.count -gt 0)
            {
                $message = "$($DefinedJob.Name): Found Validation Tests to perform for JobResults"
                Write-Verbose -Message $message
                $message = "$($DefinedJob.Name): Test JobResults for Validations ($($DefinedJob.ResultsValidation.Keys -join ','))"
                Write-Verbose -Message $message
                switch (Test-JSMJobResult -ResultsValidation $DefinedJob.ResultsValidation -JobResults $JobResults)
                {
                    $true
                    {
                        $message = "$($DefinedJob.Name): JobResults PASSED Validations ($($DefinedJob.ResultsValidation.Keys -join ','))"
                        Write-Verbose -Message $message
                    }
                    $false
                    {
                        $message = "$($DefinedJob.Name): JobResults FAILED Validations ($($DefinedJob.ResultsValidation.Keys -join ','))"
                        Write-Warning -Message $message
                        $newlyFailedDefinedJobs += $($DefinedJob | Select-Object -Property *,@{n='FailureType';e={'ResultsValidation'}})
                        continue nextDefinedJob
                    }
                }
                }
            else
            {
                $message = "$($DefinedJob.Name): No Validation Tests defined for JobResults"
                Write-Verbose -Message $message
            }
            Try
            {
                $message = "$($DefinedJob.Name): Receive Results to Variable $($DefinedJob.ResultsVariableName)"
                Write-Verbose -Message $message
                Set-Variable -Name $DefinedJob.ResultsVariableName -Value $JobResults -ErrorAction Stop -Scope Global
                Write-Verbose -Message $message
                $ThisDefinedJobSuccessfullyCompleted = $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $NewlyFailedDefinedJobs += $($DefinedJob | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariable'}})
                Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
                Continue nextDefinedJob
            }
            if ($DefinedJob.ResultsKeyVariableNames.count -ge 1)
            {
                foreach ($v in $DefinedJob.ResultsKeyVariableNames)
                {
                    try
                    {
                        $message = "$($DefinedJob.Name): Receive Key Results to Variable $v"
                        Write-Verbose -Message $message
                        Set-Variable -Name $v -Value $($JobResults.$($v)) -ErrorAction Stop -Scope Global
                        Write-Verbose -Message $message
                        $ThisDefinedJobSuccessfullyCompleted = $true
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        $NewlyFailedDefinedJobs += $($DefinedJob | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariablefromKey'}})
                        Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
                        $ThisDefinedJobSuccessfullyCompleted = $false
                        Continue nextDefinedJob
                    }
                }
            }
            if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
            {
                $message = "$($DefinedJob.Name): Successfully Completed"
                Write-Verbose -Message $message
                Update-JSMJobSetStatus -Job $DefinedJob.name -Message 'Job Successfully Completed' -Status $true
                $Global:CompletedJobs.$($DefinedJob.name) = $true
                #Run PostJobCommands
                if ([string]::IsNullOrWhiteSpace($DefinedJob.PostJobCommands) -eq $false)
                {
                    $message = "$($DefinedJob.Name): Found PostJobCommands."
                    Write-Verbose -Message $message
                    $message = "$($DefinedJob.Name): Run PostJobCommands"
                    try
                    {
                        Write-Verbose -Message $message
                        . $($DefinedJob.PostJobCommands)
                        Write-Verbose -Message $message
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                    }
                }
                #Remove Jobs and Variables - expand the try catch to each operation (job removal and variable removal)
                try
                {
                    Remove-RSJob $RSJobs -ErrorAction Stop
                    if ($DefinedJob.RemoveVariablesAtCompletion.count -gt 0)
                    {
                        $message = "$($DefinedJob.name): Removing Variables $($DefinedJob.RemoveVariablesAtCompletion -join ',')"
                        Write-Verbose -Message $message
                        Remove-Variable -Name $DefinedJob.RemoveVariablesAtCompletion -ErrorAction Stop -Scope Global
                        Write-Verbose -Message $message
                    }
                    Remove-Variable -Name JobResults -ErrorAction Stop
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                }
                [gc]::Collect()
                Start-Sleep -Seconds 5
            }#if $thisDefinedJobSuccessfullyCompleted
            #remove variables JobResults,SplitData,YourSplitData . . .
        }#foreach
        if ($newlyCompletedJobs.Count -ge 1)
        {
            Write-Verbose -Message "Finished Processing Newly Completed Jobs"
        }
        #do something here with NewlyFailedJobs
        if ($newlyFailedDefinedJobs.count -ge 1)
        {
            foreach ($nfdj in $newlyFailedDefinedJobs)
            {
                switch ($Global:FailedJobs.ContainsKey($nfdj.name))
                {
                    $true
                    {
                        $Global:FailedJobs.$($nfdj.name).FailureCount++
                        $Global:FailedJobs.$($nfdj.name).FailureType += $nfdj.FailureType
                    }
                    $false
                    {
                        $Global:FailedJobs.$($nfdj.name) = [PSCustomObject]@{
                            FailureCount = 1
                            FailureType = @($nfdj.FailureType)
                        }
                    }
                }
                #if JobFailureRetryLimit exceeded then abort the loop
                if (($nfdj.JobFailureRetryLimit -ne $null -and $Global:FailedJobs.$($nfdj.name).FailureCount -gt $nfdj.JobFailureRetryLimit) -or $Global:FailedJobs.$($nfdj.name).FailureCount -gt $JobFailureRetryLimit)
                {
                    $message = "$($nfdj.Name): Exceeded JobFailureRetry Limit. Ending Job Processing Loop. Failure Count: $($Global:FailedJobs.$($nfdj.name).FailureCount). FailureTypes: $($Global:FailedJobs.$($nfdj.name).FailureType -join ',')"
                    Write-Warning -Message $message
                    $JobProcessingLoopFailure = $true
                    $StopLoop = $true
                }
                else #otherwise remove the jobs and we'll try again next loop
                {
                    try
                    {
                        $message = "$($nfdj.Name): Removing Failed RSJob(s)."
                        Write-Verbose -Message $message
                        Get-RSJob -Name $nfdj.name | Remove-RSJob -ErrorAction Stop
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
        if ($Interactive)
        {
            $Script:AllCurrentJobs = Get-RSJob | Where-Object -FilterScript {$_.Name -notin $Global:CompletedJobs.Keys}
            $CurrentlyRunningJobs = $script:AllCurrentJobs | Select-Object -ExpandProperty Name
            Write-Verbose -Message "==========================================================================" -Verbose
            Write-Verbose -Message "$(Get-Date)" -Verbose
            Write-Verbose -Message "==========================================================================" -Verbose
            Write-Verbose -Message "Currently Running Jobs: $(($CurrentlyRunningJobs | sort-object) -join ',')" -Verbose
            Write-Verbose -Message "==========================================================================" -Verbose
            Write-Verbose -Message "Completed Jobs: $(($Global:CompletedJobs.Keys | sort-object) -join ',' )" -Verbose
            Write-Verbose -Message "==========================================================================" -Verbose
        }
        if ($PeriodicReport -eq $true)
        {
            #add code here to periodically report on progress via a job?
            Send-JSMPeriodicReport -PeriodicReportSettings $PeriodicReportSettings -RequiredJobs $Global:RequiredJobs -stopwatch $Global:stopwatch
        }
        if ($LoopOnce -eq $true)
        {
            $StopLoop = $true
        }
        else
        {
            Start-Sleep -Seconds $SleepSecondsBetweenJobCheck
        }
    }
    Until
    ($null -eq ((Compare-Object -DifferenceObject @($Global:CompletedJobs.Keys) -ReferenceObject @($Global:RequiredJobs.Name))) -or $StopLoop)
    if ($JobProcessingLoopFailure)
    {
        $False
    }
    else
    {
        $true
    }
}
