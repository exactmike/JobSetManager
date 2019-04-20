function Start-JSMNewJobCompletionProcess
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [hashtable]$JobCompletion
        ,
        [parameter(Mandatory)]
        [psobject[]]$JobRequired
        ,
        [switch]$SuppressVariableRemoval
    )
    $CompletedRSJobs = @(Get-RSJob -State Completed | Where-Object -FilterScript {$_.Name -in $JobRequired.Name -and $_.Name -notin $JobCompletion.Keys})
    if ($CompletedRSJobs.count -ge 1)
    {
        $skipBatchJobs = @{}
        $PotentialNewJobCompletions = @(
            :nextRSJob foreach ($rsJob in $CompletedRSJobs)
            {
                #skip examining this job if another in the same batch has already been examined in this loop
                if ($skipBatchJobs.ContainsKey($rsJob.name))
                {
                    continue nextRSJob
                }
                #Match the RS Job to the Job Definition
                $DefinedJob = @($JobRequired | Where-Object -FilterScript {$_.name -eq $rsJob.name})
                switch ($DefinedJob.Count)
                {
                    1
                    {
                        $DefinedJob = $DefinedJob[0]
                    }
                    0
                    {
                        Write-Warning -Message "Definition not found for job: $($rsjob.name). Skipping Completion."
                        continue nextRSJob
                    }
                    {$_ -gt 1}
                    {
                        Write-Warning -Message "Multiple Definition(s) found for job: $($rsjob.name). Skipping Completion."
                        continue nextRSJob
                    }
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
                        #$NewJobFailures += $($BatchRSJobs | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'SplitJobCountMismatch')
                    }
                }
                #$DefinedJob | Add-Member -MemberType NoteProperty -Name EndTime -Value (Get-Date) -Force
                $DefinedJob
            }
        )
        if ($PotentialNewJobCompletions.Count -ge 1)
        {
            $NewJobFailures = @(); $NewJobFailures = {$NewJobFailures}.Invoke()
            Write-Verbose -Message "Found $($PotentialNewJobCompletions.Count) Potential Newly Completed Job(s) to Process: $($PotentialNewJobCompletions.Name -join ',')"
            :nextDefinedJob foreach ($j in $PotentialNewJobCompletions)
            {
                $ThisAttempt = Get-JSMJobAttempt -JobName $j.name -Active $true -StopType 'None'
                $ThisAttemptNo = $ThisAttempt | Select-Object -ExpandProperty Attempt
                $ThisDefinedJobSuccessfullyCompleted = $false
                $message = "$($j.name): Get Job Engine Job(s)"
                try
                {
                    Write-Verbose -Message $message
                    $RSJobs = @(Get-RSJob -Name $j.Name -ErrorAction Stop)
                    Write-Verbose -Message $message
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 402
                }
                catch
                {
                    $myerror = $_
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror.tostring()
                    $NewJobFailures.add($($job | Select-Object -Property *,@{n='FailureType';e={'GetJob'}}))
                    Add-JSMJobFailure -Name $j.Name -FailureType 'GetJob' -Attempt $ThisAttempt
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 403
                    Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                    continue nextDefinedJob
                }
                if ($j.JobSplit -gt 1 -and ($RSJobs.Count -eq $j.JobSplit) -eq $false)
                {
                    $message = "$($j.name): Job Engine Job Count does not match JSM Job SplitJob specification."
                    Write-Warning -Message $message
                    $NewJobFailures.add($($job | Select-Object -Property *,@{n='FailureType';e={'SplitJobCount'}}))
                    Add-JSMJobFailure -Name $j.Name -FailureType 'SplitJobCount' -Attempt $ThisAttempt
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 407
                    Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                    continue nextDefinedJob
                }
                else
                {
                    $message = "$($j.name): Job Engine Job Count Matches JSM Job SplitJob specification."
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 406
                }
                #Log any Errors from the RS Job
                if ($RSJobs.HasErrors -contains $true)
                {
                    $message = "$($j.Name): reported errors"
                    Write-Warning -Message $message
                    $Errors = foreach ($rsJob in $RSJobs) {if ($rsJob.Error.count -gt 0) {$rsJob.Error.getenumerator()}}
                    if ($Errors.count -gt 0)
                    {
                        $ErrorStrings = $Errors | ForEach-Object -Process {$_.ToString()}
                        Write-Warning -Message $($($j.Name + ' Errors: ') + $($ErrorStrings -join '|'))
                    }
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 411
                }#if
                else
                {
                    $message = "$($j.Name): reported NO errors"
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 410
                }
                #Receive the RS Job Results to generic JobResults variable.
                try
                {
                    $message = "$($j.Name): Receive Results to Generic JobResults variable pending validation"
                    Write-Verbose -Message $message
                    $JobResults = Receive-RSJob -Job $RSJobs -ErrorAction Stop
                    Write-Verbose -Message $message
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 414
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $NewJobFailures.Add($($j | Select-Object -Property *,@{n='FailureType';e={'ReceiveJob'}}))
                    Add-JSMJobFailure -Name $j.Name -FailureType 'ReceiveJob' -Attempt $ThisAttempt
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 415
                    Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                    Continue nextDefinedJob
                }
                #Validate the JobResultsVariable
                if ($j.ResultsValidation.count -gt 0)
                {
                    $message = "$($j.Name): Found Validation Tests to perform for JobResults"
                    Write-Verbose -Message $message
                    $message = "$($j.Name): Test JobResults for Validations ($($j.ResultsValidation.Keys -join ','))"
                    Write-Verbose -Message $message
                    switch (Test-JSMJobResult -ResultsValidation $j.ResultsValidation -JobResults $JobResults -JobName $j.Name)
                    {
                        $true
                        {
                            $message = "$($j.Name): JobResults PASSED Validations ($($j.ResultsValidation.Keys -join ','))"
                            Write-Verbose -Message $message
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 440
                        }
                        $false
                        {
                            $message = "$($j.Name): JobResults FAILED Validations ($($j.ResultsValidation.Keys -join ','))"
                            Write-Warning -Message $message
                            $NewJobFailures.add($($j | Select-Object -Property *,@{n='FailureType';e={'ResultsValidation'}}))
                            Add-JSMJobFailure -Name $j.Name -FailureType 'ResultsValidation' -Attempt $ThisAttempt
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 441
                            Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                            continue nextDefinedJob
                        }
                    }
                    }
                else
                {
                    $message = "$($j.Name): No Validation Tests defined for JobResults"
                    Write-Verbose -Message $message
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 442
                }
                #Receive the Job Results to the specified variable(s) in the job definition
                switch ($j.ResultsKeyVariableNames.count -ge 1)
                {
                    $true
                    {
                        foreach ($v in $j.ResultsKeyVariableNames)
                        {
                            try
                            {
                                $message = "$($j.Name): Receive Key Results to Variable $v"
                                Write-Verbose -Message $message
                                Set-Variable -Name $v -Value $($JobResults.$($v)) -ErrorAction Stop -Scope Global
                                Write-Verbose -Message $message
                                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 452
                                $ThisDefinedJobSuccessfullyCompleted = $true
                            }
                            catch
                            {
                                $myerror = $_.tostring()
                                Write-Warning -Message $message
                                Write-Warning -Message $myerror
                                $NewJobFailures.Add($($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariablefromKey'}}))
                                Add-JSMJobFailure -Name $j.Name -FailureType 'SetResultsVariablefromKey' -Attempt $ThisAttempt
                                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 453
                                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                                $ThisDefinedJobSuccessfullyCompleted = $false
                                Continue nextDefinedJob
                            }
                        }
                    }
                    $false
                    {
                        Try
                        {
                            $message = "$($j.Name): Receive Results to Variable $($j.ResultsVariableName)"
                            Write-Verbose -Message $message
                            Set-Variable -Name $j.ResultsVariableName -Value $JobResults -ErrorAction Stop -Scope Global
                            Write-Verbose -Message $message
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 450
                            $ThisDefinedJobSuccessfullyCompleted = $true
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            $NewJobFailures.add($($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariable'}}))
                            Add-JSMJobFailure -Name $j.Name -FailureType 'SetResultsVariable' -Attempt $ThisAttempt
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 451
                            Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                            Continue nextDefinedJob
                        }
                    }
                }
                if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
                {
                    $message = "$($j.Name): Successfully Completed"
                    Write-Verbose -Message $message
                    Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 460
                    Add-JSMJobCompletion -Name $j.Name
                    Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType 'Complete'
                    #Run PostJobCommands
                    if ([string]::IsNullOrWhiteSpace($j.PostJobCommands) -eq $false)
                    {
                        $message = "$($j.Name): Found PostJobCommands."
                        Write-Verbose -Message $message
                        $message = "$($j.Name): Run PostJobCommands"
                        try
                        {
                            Write-Verbose -Message $message
                            . $($j.PostJobCommands)
                            Write-Verbose -Message $message
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 458
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 459
                        }
                    }
                    #Remove Jobs and Variables - expand the try catch to each operation (job removal and variable removal)
                    try
                    {
                        Remove-RSJob $RSJobs -ErrorAction Stop
                        if ($j.RemoveVariablesAtCompletion.count -gt 0 -and $true -ne $SuppressVariableRemoval)
                        {
                            $message = "$($j.name): Removing Variables $($j.RemoveVariablesAtCompletion -join ',')"
                            Write-Verbose -Message $message
                            Remove-Variable -Name $j.RemoveVariablesAtCompletion -ErrorAction Stop -Scope Global
                            Write-Verbose -Message $message
                        }
                        Remove-Variable -Name JobResults -ErrorAction Stop
                        Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 470
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 471
                    }
                    Add-JSMProcessingStatusEntry -Job $j.name -Message "Job Completed Successfully" -Status $true -EventID 498
                }#if $thisDefinedJobSuccessfullyCompleted
                #remove variables JobResults,SplitData,YourSplitData . . .
            }#foreach
            Write-Verbose -Message "Finished Processing Potential Newly Completed Jobs"
            $NewJobFailures
        }
    }
}