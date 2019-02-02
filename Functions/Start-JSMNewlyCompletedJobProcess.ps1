function Start-JSMNewlyCompletedJobProcess
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [hashtable]$CompletedJob
        ,
        [parameter(Mandatory)]
        [psobject[]]$RequiredJob
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
                $DefinedJob | Add-Member -MemberType NoteProperty -Name EndTime -Value (Get-Date) -Force
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
                Write-Verbose -Message "$($j.name): RS Job Newly completed"
                $message = "$($j.name): Match newly completed RSJob to Defined Job."
                try
                {
                    Write-Verbose -Message $message
                    $RSJobs = @(Get-RSJob -Name $j.Name -ErrorAction Stop)
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                }
                catch
                {
                    $myerror = $_
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror.tostring()
                    $NewlyFailedJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'GetJob'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'GetJob'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                    continue nextDefinedJob
                }
                if ($j.JobSplit -gt 1 -and ($RSJobs.Count -eq $j.JobSplit) -eq $false)
                {
                    $message = "$($j.name): RSJob Count does not match Defined Job SplitJob specification."
                    Write-Warning -Message $message
                    $NewlyFailedJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'SplitJobCount'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'SplitJobCount'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                    continue nextDefinedJob
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
                }#if
                #Receive the RS Job Results to generic JobResults variable.
                try
                {
                    $message = "$($j.Name): Receive Results to Generic JobResults variable pending validation"
                    Write-Verbose -Message $message
                    $JobResults = Receive-RSJob -Job $RSJobs -ErrorAction Stop
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'ReceiveJob'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'ReceiveJob'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
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
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                        }
                        $false
                        {
                            $message = "$($j.Name): JobResults FAILED Validations ($($j.ResultsValidation.Keys -join ','))"
                            Write-Warning -Message $message
                            $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'ResultsValidation'}})
                            Add-JSMFailedJob -Name $j.Name -FailureType 'ResultsValidation'
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                            continue nextDefinedJob
                        }
                    }
                    }
                else
                {
                    $message = "$($j.Name): No Validation Tests defined for JobResults"
                    Write-Verbose -Message $message
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
                                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                                $ThisDefinedJobSuccessfullyCompleted = $true
                            }
                            catch
                            {
                                $myerror = $_.tostring()
                                Write-Warning -Message $message
                                Write-Warning -Message $myerror
                                $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariablefromKey'}})
                                Add-JSMFailedJob -Name $j.Name -FailureType 'SetResultsVariablefromKey'
                                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
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
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                            $ThisDefinedJobSuccessfullyCompleted = $true
                        }
                        catch
                        {
                            $myerror = $_.tostring()
                            Write-Warning -Message $message
                            Write-Warning -Message $myerror
                            $NewlyFailedJobs += $($j | Select-Object -Property *,@{n='FailureType';e={'SetResultsVariable'}})
                            Add-JSMFailedJob -Name $j.Name -FailureType 'SetResultsVariable'
                            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                            Continue nextDefinedJob
                        }
                    }
                }
                if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
                {
                    $message = "$($j.Name): Successfully Completed"
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
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
                        if ($j.RemoveVariablesAtCompletion.count -gt 0)
                        {
                            $message = "$($j.name): Removing Variables $($j.RemoveVariablesAtCompletion -join ',')"
                            Write-Verbose -Message $message
                            Remove-Variable -Name $j.RemoveVariablesAtCompletion -ErrorAction Stop -Scope Global
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
            Write-Verbose -Message "Finished Processing Potential Newly Completed Jobs"
            $NewlyFailedJobs
        }
    }
}