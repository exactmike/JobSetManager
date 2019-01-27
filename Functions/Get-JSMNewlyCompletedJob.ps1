function Get-JSMNewlyCompletedJob
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
    #$PotentialNewlyCompletedJobs = @{}
    #$CompletedRSJobs | ForEach-Object {$PotentialNewlyCompletedJobs.$($_.Name) =  $true}
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
                $DefinedJob = @($Script:RequiredJob | Where-Object -FilterScript {$_.name -eq $rsJob.name})
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
            $NewlyCompletedJob = @{}
            Write-Verbose -Message "Found $($PotentialNewlyCompletedJobs.Count) Potential Newly Completed Job(s) to Process: $($PotentialNewlyCompletedJobs.Name -join ',')"
            :nextDefinedJob foreach ($DefinedJob in $PotentialNewlyCompletedJobs)
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
                    #Update-JSMJobSetStatus -Job $DefinedJob.name -Message $message -Status $true
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $NewlyFailedDefinedJobs += $($DefinedJob | Select-Object -Property *,@{n='FailureType';e={'ReceiveRSJob'}})
                    #Update-JSMJobSetStatus -Job $DefinedJob.name -Message $message -Status $false
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
                switch ($DefinedJob.ResultsKeyVariableNames.count -ge 1)
                {
                    $true
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
                                #Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
                                $ThisDefinedJobSuccessfullyCompleted = $false
                                Continue nextDefinedJob
                            }
                        }
                    }
                    $false
                    {
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
                            #Update-JSMJobSetStatus -Job $Job.name -Message $message -Status $false
                            Continue nextDefinedJob
                        }
                    }
                }
                if ($ThisDefinedJobSuccessfullyCompleted -eq $true)
                {
                    $message = "$($DefinedJob.Name): Successfully Completed"
                    Write-Verbose -Message $message
                    #Update-JSMJobSetStatus -Job $DefinedJob.name -Message 'Job Successfully Completed' -Status $true
                    Add-JSMCompletedJob -Name $DefinedJob.Name
                    $NewlyCompletedJob.$($DefinedJob.Name)
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
            Write-Verbose -Message "Finished Processing Potential Newly Completed Jobs"
            $NewlyCompletedJob
            $NewlyFailedDefinedJobs
        }
    }
}