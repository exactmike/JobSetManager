#Parameters to add:  Conditions Array (like condition = $true), JobDefinitionsPath, Interactive,Settings
param(
    $Settings
    ,
    $JobDefinitions
    ,
    [switch]$Interactive
)
##################################################################
#Define all Required Jobs
##################################################################
#Only the jobs that meet the settings conditions or not conditions are required
$RequiredJobFilter = [scriptblock] {
    (($_.OnCondition.count -eq 0) -or (Test-JobCondition -JobConditionList $_.OnCondition -ConditionValuesObject $Settings -TestFor $True)) -and
    (($_.OnNOTCondition.count -eq 0) -or (Test-JobCondition -JobConditionList $_.OnNotCondition -ConditionValuesObject $Settings -TestFor $False))
}
$RequiredJobs = @($JobDefinitions | Where-Object -FilterScript $RequiredJobFilter)
if ($RequiredJobs.Count -eq 0)
{
    Write-Verbose -Message "No Required Jobs Found"
    Return $null
}
##################################################################
#Prep for Jobs Loop
##################################################################
$CompletedJobs = @{} #Will add JobName as Key and Value as True when a job is completed
$FailedJobs = @{} #Will add JobName as Key and value as array of failures that occured
##################################################################
#Loop to manage Jobs to successful completion or gracefully handled failure
##################################################################
Do
{
    #Get existing jobs and check for those that are running and/or newly completed
    $CurrentlyExistingRSJobs = @(Get-RSJob)
    $AllCurrentJobs = $CurrentlyExistingRSJobs | Where-Object -FilterScript {$_.Name -notin $CompletedJobs.Keys}
    $newlyCompletedRSJobs = $AllCurrentJobs | Where-Object -FilterScript {$_.Completed -eq $true}
    $newlyFailedDefinedJobs = @()
    #Check for jobs that meet their start criteria
    $JobsToStartFilter = [scriptblock]{
        ($_.Name -notin $completedJobs.Keys) -and
        ($_.Name -notin $AllCurrentJobs.Name) -and
        (Test-JobCondition -JobConditionList $_.DependsOnJobs -ConditionValuesObject $completedJobs.Keys -TestFor $true)
    }
    $JobsToStart = @($RequiredJobs | Where-Object -FilterScript $JobsToStartFilter)
    if ($JobsToStart.Count -ge 1)
    {
        $message = "Found $($JobsToStart.Count) Jobs Ready To Start"
        Write-Log -message $message -entryType Notification -verbose
        foreach ($job in $jobsToStart)
        {
            $message = "$($job.Name): Ready to Start"
            Write-Log -message $message -entrytype Notification -verbose
            Update-ProcessStatus -Job $Job.name -Message $message -Status $true
        }
        #Start the jobs
        :nextJobToStart foreach ($job in $JobsToStart)
        {
            #Prepare the Start-RSJob Parameters
            $StartRSJobParams = $job.StartRSJobParams
            $StartRSJobParams.Name = $job.Name
            #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartRSJobParameters property)
            if ($job.ArgumentList.count -ge 1)
            {
                $message = "$($job.Name): Found ArgumentList to populate with live variables."
                Write-Log -Message $message -EntryType Notification
                try
                {
                    $StartRSJobParams.ArgumentList = @(
                        foreach ($a in $job.ArgumentList)
                        {
                            $message = "$($job.Name): Get Argument List Variable $a"
                            Write-Log -Message $message -EntryType Attempting
                            Get-Variable -Name $a -ValueOnly -ErrorAction Stop
                            Write-Log -Message $message -EntryType Succeeded                                    
                        }
                    )
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog
                    continue nextJobToStart
                }
            }
            #Run the PreJobCommands
            if ([string]::IsNullOrWhiteSpace($job.PreJobCommands) -eq $false)
            {
                $message = "$($job.Name): Found PreJobCommands to run."
                Write-Log -Message $message -EntryType Notification
                $message = "$($job.Name): Run PreJobCommands"
                try
                {
                    Write-Log -Message $message -EntryType Attempting
                    . $($job.PreJobCommands)
                    Write-Log -Message -EntryType Succeeded
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog
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
                    Write-Log -Message $message -EntryType Attempting -Verbose
                    $DataToSplit = Get-Variable -Name $job.JobSplitDataVariableName -ValueOnly -ErrorAction Stop
                    Write-Log -Message $message -EntryType Succeeded -Verbose
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog
                    continue nextJobToStart
                }
                try
                {
                    $message = "$($job.Name): Calculate the split ranges for the data $($job.jobsplitDataVariableName) for $($job.JobSplit) batch jobs"
                    Write-Log -Message $message -EntryType Attempting -Verbose    
                    $splitGroups = New-SplitArrayRange -inputArray $DataToSplit -parts $job.JobSplit -ErrorAction Stop
                    Write-Log -Message $message -EntryType Succeeded -Verbose
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog
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
                        Write-Log -Message $message -EntryType Attempting -Verbose
                        Start-RSJob @StartRSJobParams | Out-Null
                        Write-Log -Message $message -EntryType Succeeded -Verbose
                        Update-ProcessStatus -Job $Job.name -Message $message -Status $true
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                        Write-Log -Message $myerror -ErrorLog
                        Update-ProcessStatus -Job $Job.name -Message $message -Status $false
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
                    Write-Log -Message $message -EntryType Attempting -Verbose
                    Start-RSJob @StartRSJobParams | Out-Null
                    Write-Log -Message $message -EntryType Succeeded -Verbose              
                    Update-ProcessStatus -Job $Job.name -Message $message -Status $true
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog
                    Update-ProcessStatus -Job $Job.name -Message $message -Status $false
                    continue nextJobToStart
                }
            }
        }
        $message = "Finished Processing Jobs Ready To Start"
        Write-Log -message $message -entryType Notification -verbose
    }#if
    #Check for jobs that need to be received and validated for marking as Complete
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
                $DefinedJob = @($RequiredJobs | Where-Object -FilterScript {$_.name -eq $rsJob.name})
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
                            Write-Output -InputObject $DefinedJob
                        }           
                    }
                    else #this is a failure that needs to be raised
                    {
                        #how should we exit the loop and report what happened?
                        #$NewlyFailedJobs += $($BatchRSJobs | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'SplitJobCountMismatch')                        
                    }   
                }
                else
                {
                    Write-Output -InputObject $DefinedJob    
                }
            }
        )
    }
    if ($newlyCompletedJobs.Count -ge 1)
    {
        Write-Log -Message "Found $($newlyCompletedJobs.Count) Newly Completed Defined Job(s) to Process: $($newlyCompletedJobs.Name -join ',')" -Verbose -EntryType Notification
    }
    :nextDefinedJob foreach ($DefinedJob in $newlyCompletedJobs)
    {
        $ThisDefinedJobSuccessfullyCompleted = $false
        Write-Log -Message "$($DefinedJob.name): RS Job Newly completed" -Verbose -EntryType Notification
        $message = "$($DefinedJob.name): Match newly completed RSJob to Defined Job."
        try
        {
            Write-Log -Message $message -EntryType Attempting
            $RSJobs = @(Get-RSJob -Name $DefinedJob.Name -ErrorAction Stop)
            Write-Log -Message $message -EntryType Succeeded
        }
        catch
        {
            $myerror = $_
            Write-Log -Message $message -EntryType Failed -ErrorLog
            Write-Log -Message $myerror.tostring() -ErrorLog
            continue nextDefinedJob
        }
        if (($RSJobs.Count -eq $DefinedJob.JobSplit) -eq $false)
        {
            $message = "$($DefinedJob.name): RSJob Count does not match Defined Job SplitJob specification."
            Write-Log -Message $message -ErrorLog -EntryType Failed
            continue nextDefinedJob
        }
        #Log any Errors from the RS Job
        if ($RSJobs.HasErrors -contains $true)
        {
            $message = "$($DefinedJob.Name): has errors"
            Write-Log -Message $message -ErrorLog
            $ErrorStrings = $RSJobs.Error | ForEach-Object -Process {$_.ToString()}
            Write-Log -Message $($($DefinedJob.Name + ' Errors: ') + $($ErrorStrings -join '|')) -ErrorLog
        }#if        
        #Receive the RS Job Results to generic JobResults variable.  
        try 
        {
            $message = "$($DefinedJob.Name): Receive Results to Generic JobResults variable pending validation"
            Write-Log -Message $message -entrytype Attempting -Verbose
            $JobResults = Receive-RSJob -Job $RSJobs -ErrorAction Stop            
            Write-Log -Message $message -entrytype Succeeded -Verbose
            Update-ProcessStatus -Job $Job.name -Message $message -Status $true
        }
        catch
        {
            $myerror = $_.tostring()
            Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
            Write-Log -Message $myerror -ErrorLog
            $NewlyFailedDefinedJobs += $DefinedJob
            Update-ProcessStatus -Job $Job.name -Message $message -Status $false
            Continue nextDefinedJob
        }
        #Validate the JobResultsVariable
        if ($DefinedJob.JobResultsValidation.count -gt 0)
        {
            $message = "$($DefinedJob.Name): Found Validation Tests to perform for JobResults"
            Write-Log -Message $message -EntryType Notification
            $message = "$($DefinedJob.Name): Test JobResults for Validations ($($DefinedJob.JobResultsValidation.Keys -join ','))"
            Write-Log -Message $message -EntryType Notification
            switch (Test-JobResult -JobResultsValidation $DefinedJob.JobResultsValidation -JobResults $JobResults)
            {
                $true
                {
                    $message = "$($DefinedJob.Name): JobResults PASSED Validations ($($DefinedJob.JobResultsValidation.Keys -join ','))"
                    Write-Log -Message $message -EntryType Succeeded
                }
                $false
                {
                    $message = "$($DefinedJob.Name): JobResults FAILED Validations ($($DefinedJob.JobResultsValidation.Keys -join ','))"   
                    Write-Log -Message $message -EntryType Failed
                    $newlyFailedDefinedJobs += $DefinedJob
                    continue nextDefinedJob
                }
            }
        }
        else
        {
            $message = "$($DefinedJob.Name): No Validation Tests defined for JobResults"
            Write-Log -Message $message -EntryType Notification            
        }
        Try
        {
            $message = "$($DefinedJob.Name): Receive Results to Variable $($DefinedJob.ResultsVariableName)"            
            Write-Log -Message $message -EntryType Attempting
            Set-Variable -Name $DefinedJob.ResultsVariableName -Value $JobResults -ErrorAction Stop
            Write-Log -Message $message -EntryType Succeeded
            $ThisDefinedJobSuccessfullyCompleted = $true            
        }
        catch
        {
            $myerror = $_.tostring()
            Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
            Write-Log -Message $myerror -ErrorLog
            $NewlyFailedDefinedJobs += $DefinedJob
            Update-ProcessStatus -Job $Job.name -Message $message -Status $false
            Continue nextDefinedJob
        }
        if ($DefinedJob.ResultsKeyVariableNames.count -ge 1)
        {
            foreach ($v in $DefinedJob.ResultsKeyVariableNames)
            {
                try
                {
                    $message = "$($DefinedJob.Name): Receive Key Results to Variable $v"
                    Write-Log -Message $message -entrytype Attempting -Verbose
                    Set-Variable -Name $v -Value $($JobResults.$($v)) -ErrorAction Stop
                    Write-Log -Message $message -entrytype Succeeded -Verbose
                    $ThisDefinedJobSuccessfullyCompleted = $true                             
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                    Write-Log -Message $myerror -ErrorLog                    
                    $newlyFailedDefinedJobs += $($DefinedJob |  Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'RSJobReceiveSubResults')
                    $ThisDefinedJobSuccessfullyCompleted = $false
                    Continue nextDefinedJob
                }
            }
        }
        if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
        {
            Update-ProcessStatus -Job $DefinedJob.name -Message 'Job Successfully Completed' -Status $true            
            $CompletedJobs.$($DefinedJob.name) = $true
            #Run PostJobCommands
            if ([string]::IsNullOrWhiteSpace($DefinedJob.PostJobCommands) -eq $false)
            {
                . $($DefinedJob.PostJobCommands)
            }
            #Remove Jobs and Variables - expand the try catch to each operation (job removal and variable removal)
            try
            {
                Remove-RSJob $RSJobs -ErrorAction Stop
                if ($DefinedJob.RemoveVariablesAtCompletion.count -gt 0)
                {
                    $message = "$($DefinedJob.name): Removing Variables $($DefinedJob.RemoveVariablesAtCompletion -join ',')"
                    Write-Log -Message $message -EntryType Notification -Verbose
                    Remove-Variable -Name $DefinedJob.RemoveVariablesAtCompletion -ErrorAction Stop
                }
                Remove-Variable -Name JobResults -ErrorAction Stop                  
            }
            catch
            {
                
            }
            [gc]::Collect()
            Start-Sleep -Seconds 10
        }#if $thisDefinedJobSuccessfullyCompleted
        #remove variables JobResults,SplitData,YourSplitData . . .
    }#foreach
    if ($newlyCompletedJobs.Count -ge 1)
    {
        Write-Log -Message "Finished Processing Newly Completed Jobs" -EntryType Notification -Verbose
    }
    #do something here with NewlyFailedJobs
    if ($Interactive)
    {
        Write-Verbose -Message "==========================================================================" -Verbose
        Write-Verbose -Message "$(Get-Date)" -Verbose
        Write-Verbose -Message "==========================================================================" -Verbose
        Write-Verbose -Message "Completed Jobs: $(($completedJobs.Keys | sort-object) -join ',' )" -Verbose
        Write-Verbose -Message "==========================================================================" -Verbose
        $WaitingOnJobs = $RequiredJobs.name | Where-Object -FilterScript {$_ -notin $CompletedJobs.Keys}
        $AllCurrentJobs = Get-RSJob | Where-Object -FilterScript {$_.Name -notin $CompletedJobs.Keys}
        $CurrentlyRunningJobs = $AllCurrentJobs | Select-Object -ExpandProperty Name
        Write-Verbose -Message "Currently Running Jobs: $(($CurrentlyRunningJobs | sort-object) -join ',')" -Verbose
        Write-Verbose -Message "==========================================================================" -Verbose
    }
    Start-Sleep -Seconds $Settings.SleepSecondsBetweenRSJobCheck
}
Until
(((Compare-Object -DifferenceObject @($CompletedJobs.Keys) -ReferenceObject @($RequiredJobs.Name)) -eq $null))