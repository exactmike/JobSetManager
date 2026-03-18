function Start-JSMNewJobCompletionProcess
{
    <#
    .SYNOPSIS
        Processes newly completed jobs: receives results, validates, assigns variables, and cleans up.
    .DESCRIPTION
        Scans the native job list for jobs in Completed state that match required job definitions
        and have not yet been recorded as completions. For each, receives results, runs validation,
        assigns results to configured variables, records completion, runs post-job commands, and
        removes the underlying PS job. Returns any job failure objects for jobs that fail validation
        or result assignment.
    .PARAMETER JobCompletion
        A hashtable of already-completed job names (keys). Used to skip already-processed jobs.
    .PARAMETER JobRequired
        The full list of job definition objects for this job set.
    .PARAMETER SuppressVariableRemoval
        When specified, skips removal of variables listed in RemoveVariablesAtCompletion.
    .EXAMPLE
        PS C:\> Start-JSMNewJobCompletionProcess -JobCompletion $completions -JobRequired $jobs

        Processes any newly completed jobs and returns failure objects for any that failed.
    .OUTPUTS
        [pscustomobject[]] job failure objects, or nothing if all succeeded.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [hashtable]$JobCompletion
        ,
        [parameter(Mandatory)]
        [hashtable]$JobRequired
        ,
        [switch]$SuppressVariableRemoval
    )
    # Find job definitions that have newly completed underlying jobs
    $PotentialNewJobCompletions = @(
        :nextDefinedJob foreach ($jr in $JobRequired.Values)
        {
            if ($jr.Name -in $JobCompletion.Keys) { continue nextDefinedJob }
            if ($jr.JobSplit -gt 1)
            {
                # Split job: all sub-jobs must be in Completed state
                $subNames = if ($null -ne $script:SplitJobGroups) { $script:SplitJobGroups[$jr.Name] } else { $null }
                if (-not $subNames -or $subNames.Count -eq 0) { continue nextDefinedJob }
                $subJobs = @(Get-Job | Where-Object { $_.Name -in $subNames })
                if ($subJobs.Count -ne $jr.JobSplit) { continue nextDefinedJob }
                if ($subJobs | Where-Object { $_.State -ne 'Completed' }) { continue nextDefinedJob }
                $jr
            }
            else
            {
                # Regular job: check for Completed state by name
                $nJob = Get-Job -Name $jr.Name -ErrorAction SilentlyContinue
                if ($null -ne $nJob -and $nJob.State -eq 'Completed')
                {
                    $jr
                }
            }
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
                if ($j.JobSplit -gt 1)
                {
                    $NativeJobs = @(Get-Job | Where-Object { $_.Name -in $script:SplitJobGroups[$j.Name] } -ErrorAction Stop)
                }
                else
                {
                    $NativeJobs = @(Get-Job -Name $j.Name -ErrorAction Stop)
                }
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 402
            }
            catch
            {
                $myerror = $_
                Write-Warning -Message $message
                Write-Warning -Message $myerror.tostring()
                $NewJobFailures.add($($j | Select-Object -Property *,@{n='FailureType';e={'GetJob'}}))
                Add-JSMJobFailure -Name $j.Name -FailureType 'GetJob' -Attempt $ThisAttempt
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 403
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                continue nextDefinedJob
            }
            if ($j.JobSplit -gt 1 -and ($NativeJobs.Count -eq $j.JobSplit) -eq $false)
            {
                $message = "$($j.name): Job Engine Job Count does not match JSM Job SplitJob specification."
                Write-Warning -Message $message
                $NewJobFailures.add($($j | Select-Object -Property *,@{n='FailureType';e={'SplitJobCount'}}))
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
            #Log any Errors from the native jobs
            $hasErrors = $false
            $Errors = foreach ($nJob in $NativeJobs)
            {
                if ($nJob.ChildJobs[0].Error.Count -gt 0)
                {
                    $hasErrors = $true
                    $nJob.ChildJobs[0].Error.GetEnumerator()
                }
            }
            if ($hasErrors)
            {
                $message = "$($j.Name): reported errors"
                Write-Warning -Message $message
                if ($Errors.count -gt 0)
                {
                    $ErrorStrings = $Errors | ForEach-Object -Process {$_.ToString()}
                    Write-Warning -Message $($($j.Name + ' Errors: ') + $($ErrorStrings -join '|'))
                }
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 411
            }
            else
            {
                $message = "$($j.Name): reported NO errors"
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 410
            }
            #Receive the Job Results to generic JobResults variable.
            try
            {
                $message = "$($j.Name): Receive Results to Generic JobResults variable pending validation"
                Write-Verbose -Message $message
                $JobResults = Receive-Job -Job $NativeJobs -ErrorAction Stop
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
                #Remove Jobs and Variables
                try
                {
                    Remove-Job -Job $NativeJobs -ErrorAction Stop
                    # Clean up SplitJobGroups tracking
                    if ($null -ne $script:SplitJobGroups -and $script:SplitJobGroups.ContainsKey($j.Name))
                    {
                        $script:SplitJobGroups.Remove($j.Name)
                    }
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
        }#foreach
        Write-Verbose -Message "Finished Processing Potential Newly Completed Jobs"
        $NewJobFailures
    }
}
