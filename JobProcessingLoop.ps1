#Parameters to add:  Conditions Array (like condition = $true), JobDefinitionsPath, VariablesToCreate,Interactive,Settings
param(
    $Settings
    ,
    $JobDefinitions
    ,
    $VariablesToCreate
    ,
    [switch]$Interactive
)
#Should conditions be non-boolean capable?
##################################################################
#Create required variables (for use in Jobs/JobArguments)
##################################################################

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
    #Check for jobs that have failed too many times so that we need to abort the processing
    $CurrentlyExistingRSJobs = @(Get-RSJob)
    $AllCurrentJobs = $CurrentlyExistingRSJobs | Where-Object -FilterScript {$_.Name -notin $CompletedJobs.Keys}
    $newlyCompletedRSJobs = $AllCurrentJobs | Where-Object -FilterScript {$_.Completed -eq $true}
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
        foreach ($job in $JobsToStart)
        {
            if ($job.JobSplit -gt 1)
            {
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
                    #Throw("$($job.Name): Failed to get data to start required job")
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
                    #Throw("$($job.Name): Failed to split data to start required job")
                }
                if ([string]::IsNullOrWhiteSpace($job.PreJobCommands) -eq $false)
                {
                    . $($job.PreJobCommands)
                }
                $splitjobcount = 0
                foreach ($split in $splitGroups)
                {
                    $splitjobcount++
                    $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                    $StartRSJobParams = $job.StartRSJobParams
                    $StartRSJobParams.Name = $job.Name
                    $StartRSJobParams.Batch = $job.Name
                    if ($job.ArgumentList.count -ge 1)
                    {
                        $StartRSJobParams.ArgumentList = @(
                            foreach ($a in $job.ArgumentList)
                            {Get-Variable -Name $a -ValueOnly}
                        )
                    }
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
                        #Throw("$($job.Name): Failed to start a required job")
                    }
                }
            }
            else
            {
                if ([string]::IsNullOrWhiteSpace($job.PreJobCommands) -eq $false)
                {
                    . $($job.PreJobCommands)
                }                
                try
                {
                    $message = "$($job.Name): Start Job"
                    $StartRSJobParams = $job.StartRSJobParams
                    $StartRSJobParams.Name = $job.name
                    if ($job.ArgumentList.count -ge 1)
                    {
                        $StartRSJobParams.ArgumentList = @(
                            foreach ($a in $job.ArgumentList)
                            {Get-Variable -Name $a -ValueOnly}
                        )
                    }                    
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
                    #Throw("$($job.Name): Failed to start a required job")
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
        Write-Log -Message "Found $($newlyCompletedJobs.Count) Newly Completed Job to Process: $($newlyCompletedJobs.Name -join ',')" -Verbose -EntryType Notification
    }
    :nextncj foreach ($DefinedJob in $newlyCompletedJobs)
    {
        $ThisDefinedJobSuccessfullyCompleted = $false
        Write-Log -Message "$($DefinedJob.name): RSJob Newly completed" -Verbose -EntryType Notification
        #get/match the rs job to the definition here
        Write-Log -Message "$($ncj.name): Matched newly completed job to job metadata $($DefinedJob.Name)" -entrytype Notification -Verbose        
        #Receive the RS Job Results if all related jobs are done
        if ($DefinedJob.JobSplit -gt 1)
        {
            try 
            {
                $message = "$($DefinedJob.Name): Receive Results to Variable $($DefinedJob.ResultsVariableName)"
                Write-Log -Message $message -entrytype Attempting -Verbose
                $JobResults = Receive-RSJob -Job $BatchRSJobs -ErrorAction Stop
                #if ($JobResults.count -lt 1)
                #{
                #    $NewlyFailedJobs += $($BatchRSJobs | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'GenerateResults')
                #    Continue nextDefinedJob
                #}
                Set-Variable -Name $DefinedJob.ResultsVariableName -Value $JobResults -ErrorAction Stop                      
                Write-Log -Message $message -entrytype Succeeded -Verbose
                $ThisDefinedJobSuccessfullyCompleted = $true
                Update-ProcessStatus -Job $Job.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                Write-Log -Message $myerror -ErrorLog
                $NewlyFailedJobs += $($BatchRSJobs |  Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'RSJobReceiveResults')
                Update-ProcessStatus -Job $Job.name -Message $message -Status $false
                Continue nextDefinedJob
            }
        }
        else
        {
            try 
            {
                $message = "$($DefinedJob.Name): Receive Results to Variable $($DefinedJob.ResultsVariableName)"
                Write-Log -Message $message -entrytype Attempting -Verbose
                $JobResults = Receive-RSJob -Job $DefinedJob -ErrorAction Stop
                #need to specify in the job the expected results to test for...
                #if ($JobResults.count -lt 1)
                #{
                #    $NewlyFailedJobs += $($DefinedJob | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'GenerateResults')
                #    Continue nextDefinedJob
                #}
                Set-Variable -Name $DefinedJob.ResultsVariableName -Value $JobResults -ErrorAction Stop
                Write-Log -Message $message -entrytype Succeeded -Verbose
                Update-ProcessStatus -Job $Job.name -Message $message -Status $true
                $ThisDefinedJobSuccessfullyCompleted = $true                
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Log -Message $message -EntryType Failed -ErrorLog -Verbose
                Write-Log -Message $myerror -ErrorLog
                $NewlyFailedJobs += $($DefinedJob |  Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'RSJobReceiveResults')
                Update-ProcessStatus -Job $Job.name -Message $message -Status $false
                Continue nextDefinedJob
            }
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
                    $NewlyFailedJobs += $($DefinedJob |  Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'RSJobReceiveSubResults')
                    $ThisDefinedJobSuccessfullyCompleted = $false
                    Continue nextDefinedJob
                }
            }
        }
        if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
        {
            Update-ProcessStatus -Job $Job.name -Message 'Job Successfully Completed' -Status $true            
            if ($DefinedJob.JobSplit -gt 1)
            {
                if ($BatchRSJobs | Test-All -EvaluateCondition {$_.hasErrors -eq $true})
                {
                    $message = "$($DefinedJob): Some Job(s) have errors"
                    Write-Log -Message $message -ErrorLog                           
                    $ErrorStrings = $BatchRSJobs | ForEach-Object -Process {
                        $_.Error.getenumerator() | ForEach-Object -Process {$_.tostring()}
                    }
                    Write-Log -Message $($($DefinedJob.Name + ' Errors: ') + $($ErrorStrings -join '|')) -ErrorLog                    
                }
            }
            else
            {
                #Log any Errors from the RS Job
                if ($DefinedJob.HasErrors -eq $true)
                {
                    $message = "$($DefinedJob.Name): has errors"
                    Write-Log -Message $message -ErrorLog
                    $ErrorStrings = $DefinedJob.Error.getenumerator()| ForEach-Object -Process {$_.ToString()}
                    Write-Log -Message $($($DefinedJob.Name + ' Errors: ') + $($ErrorStrings -join '|')) -ErrorLog
                }#if             
            }
            $CompletedJobs.$($DefinedJob.name) = $true
            #Run PostJobCommands
            if ([string]::IsNullOrWhiteSpace($job.PostJobCommands) -eq $false)
            {
                . $($job.PostJobCommands)
            }
            #Remove Jobs and Variables
            if ($DefinedJob.JobSplit -gt 1)
            {
                Remove-RSJob -Job $BatchRSJobs
            }
            else
            {
                Remove-RSJob -Job $ncj                
            }
            Remove-Variable -Name JobResults
            if ($DefinedJob.RemoveVariablesAtCompletion.count -gt 0)
            {
                $message = "$($DefinedJob.name): Removing Variables $($DefinedJob.RemoveVariablesAtCompletion -join ',')"
                Write-Log -Message $message -EntryType Notification -Verbose
                Remove-Variable -Name $DefinedJob.RemoveVariablesAtCompletion
            }
            [gc]::Collect()
            Start-Sleep -Seconds 10
        }#if $thisDefinedJobSuccessfullyCompleted
    }#foreach
    if ($newlyCompletedJobs.Count -ge 1)
    {
        Write-Log -Message "Finished Processing Newly Completed Jobs" -EntryType Notification -Verbose
    }
    #do something here with NewlyFailedJobs
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
    Start-Sleep -Seconds $Settings.SleepSecondsBetweenRSJobCheck
}
Until
(((Compare-Object -DifferenceObject @($CompletedJobs.Keys) -ReferenceObject @($RequiredJobs.Name)) -eq $null))