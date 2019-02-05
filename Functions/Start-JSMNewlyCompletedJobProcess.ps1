function Start-JSMNewlyCompletedJobProcess
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [hashtable]$CompletedJob
        ,
        [parameter(Mandatory)]
        [psobject[]]$RequiredJob
        ,
        [switch]$SuppressVariableRemoval
    )
    $CompletedRSJobs = @(Get-RSJob -State Completed | Where-Object -FilterScript {$_.Name -in $RequiredJob.Name -and $_.Name -notin $CompletedJobs.Keys})
    if ($CompletedRSJobs.count -ge 1)
    {
        $skipBatchJobs = @{}
        $PotentialNewlyCompletedJobs = @(
            :nextRSJob foreach ($rsJob in $CompletedRSJobs)
            {
                #skip examining this job if another in the same batch has already been examined in this loop
                if ($skipBatchJobs.ContainsKey($rsJob.name))
                {
                    continue nextRSJob
                }
                #Match the RS Job to the Job Definition
                $DefinedJob = @($RequiredJob | Where-Object -FilterScript {$_.name -eq $rsJob.name})
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
                        #$NewlyFailedJobs += $($BatchRSJobs | Add-Member -MemberType NoteProperty -Name JobFailureType -Value 'SplitJobCountMismatch')
                    }
                }
                #$DefinedJob | Add-Member -MemberType NoteProperty -Name EndTime -Value (Get-Date) -Force
                $DefinedJob
            }
        )
        if ($PotentialNewlyCompletedJobs.Count -ge 1)
        {
            $NewlyFailedJobs = @()
            Write-Verbose -Message "Found $($PotentialNewlyCompletedJobs.Count) Potential Newly Completed Job(s) to Process: $($PotentialNewlyCompletedJobs.Name -join ',')"
            :nextDefinedJob foreach ($j in $PotentialNewlyCompletedJobs)
            {
                $ThisDefinedJobSuccessfullyCompleted = $false
                $message = "$($j.name): Get Job Engine Job(s)"
                try
                {
                    Write-Verbose -Message $message
                    $RSJobs = @(Get-RSJob -Name $j.Name -ErrorAction Stop)
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 402
                }
                catch
                {
                    $myerror = $_
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror.tostring()
                    $NewlyFailedJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'GetJob'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'GetJob'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 403
                    continue nextDefinedJob
                }
                if ($j.JobSplit -gt 1 -and ($RSJobs.Count -eq $j.JobSplit) -eq $false)
                {
                    $message = "$($j.name): Job Engine Job Count does not match JSM Job SplitJob specification."
                    Write-Warning -Message $message
                    $NewlyFailedJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'SplitJobCount'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'SplitJobCount'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 407
                    continue nextDefinedJob
                }
                else
                {
                    $message = "$($j.name): Job Engine Job Count Matches JSM Job SplitJob specification."
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 406
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
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 411
                }#if
                else
                {
                    $message = "$($j.Name): reported NO errors"
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 410
                }
                #Receive the RS Job Results to generic JobResults variable.
                try
                {
                    $message = "$($j.Name): Receive Results to Generic JobResults variable pending validation"
                    Write-Verbose -Message $message
                    $JobResults = Receive-RSJob -Job $RSJobs -ErrorAction Stop
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 414
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'ReceiveJob'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'ReceiveJob'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 415
                    Continue nextDefinedJob
                }
                #Validate the JobResultsVariable
                if ($j.ResultsValidation.count -gt 0)
                {
                    $message = "$($j.Name): Found Validation Tests to perform for JobResults"
                    Write-Verbose -Message $message
                    $message = "$($j.Name): Test JobResults for Validations ($($j.ResultsValidation.Keys -join ','))"
                    Write-Verbose -Message $message
                    switch (Test-JSMJobResult -ResultsValidation $j.ResultsValidation -JobResults $JobResults)
                    {
                        $true
                        {
                            $message = "$($j.Name): JobResults PASSED Validations ($($j.ResultsValidation.Keys -join ','))"
                            Write-Verbose -Message $message
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 418
                        }
                        $false
                        {
                            $message = "$($j.Name): JobResults FAILED Validations ($($j.ResultsValidation.Keys -join ','))"
                            Write-Warning -Message $message
                            $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'ResultsValidation'}})
                            Add-JSMFailedJob -Name $j.Name -FailureType 'ResultsValidation'
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 419
                            continue nextDefinedJob
                        }
                    }
                    }
                else
                {
                    $message = "$($j.Name): No Validation Tests defined for JobResults"
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 418
                }
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
                                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 424
                                $ThisDefinedJobSuccessfullyCompleted = $true
                            }
                            catch
                            {
                                $myerror = $_.tostring()
                                Write-Warning -Message $message
                                Write-Warning -Message $myerror
                                $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariablefromKey'}})
                                Add-JSMFailedJob -Name $j.Name -FailureType 'SetResultsVariablefromKey'
                                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 425
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
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 422
                            $ThisDefinedJobSuccessfullyCompleted = $true
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariable'}})
                            Add-JSMFailedJob -Name $j.Name -FailureType 'SetResultsVariable'
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 423
                            Continue nextDefinedJob
                        }
                    }
                }
                if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
                {
                    $message = "$($j.Name): Successfully Completed"
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 426
                    Add-JSMCompletedJob -Name $j.Name
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
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 430
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 431
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
                        Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 434
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 435
                    }
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message "Job Completed Successfully" -Status $true -EventID 498
                    [gc]::Collect()
                    Start-Sleep -Seconds 5
                }#if $thisDefinedJobSuccessfullyCompleted
                #remove variables JobResults,SplitData,YourSplitData . . .
            }#foreach
            Write-Verbose -Message "Finished Processing Potential Newly Completed Jobs"
            $NewlyFailedJobs
        }
    }
}