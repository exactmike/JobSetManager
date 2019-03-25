Function Start-JSMJob
{
    <#
    .SYNOPSIS
        Starts one or more JSM Jobs using the Job Engine specified in the JobType attribute for each JSM Job
    .DESCRIPTION
        Starts one or more JSM Jobs using the Job Engine specified in the JobType attribute for each JSM Job. Runs any specified Pre-Job commands before starting the job. Returns a hashtable with keys for FailedStartJobs and SuccessStartJobs.
        Designed to be used inside of Invoke-JSMProcessingLoop but supported for stand-alone use for testing and debugging JSM Jobs.
    .EXAMPLE
        PS C:\>Start-JSMJob -Job @{Name = 'SleepJob';Message = 'A Job that Sleeps'; JobType = 'BackgroundJob'; StartJobParams = @{ScriptBlock = {Start-Sleep -Seconds 15}}}

        Name                           Value
        ----                           -----
        FailedStartJobs                {}
        SuccessStartJobs               {System.Collections.Hashtable}

        Starts a JSM Job using the native Powershell Jobs functionality and outputs success and failure records in a hashtable.
    .PARAMETER Job
        One or more JSM Job objects (PSObjects with the necessary attributes)
    .INPUTS
        [pscustomobject]
    .OUTPUTS
        [hashtable]
    #>
    [CmdletBinding()]
    param(
        [psobject[]]$Job
    )
    foreach ($j in $Job)
    {
        $message = "$($j.Name): Ready to Start"
        Write-Verbose -message $message
        Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 302
    }
    $FailedStartJobs = @(); $FailedStartJobs = {$FailedStartJobs}.invoke()
    $SuccessStartJobs = @(); $SuccessStartJobs = {$SuccessStartJobs}.invoke()
    #Start the jobs
    :nextJobToStart foreach ($j in $Job)
    {
        $PreviousAttempts = @(Get-JSMJobAttempt -JobName $j.name)
        $ThisAttemptNo = $($PreviousAttempts.Attempt | Sort-Object -Descending | Select-Object -First 1 -Unique) + 1
        Write-Verbose -Message "$($j.name) Starting Attempt $ThisAttemptNo"
        $JobType = switch ($j.JobType) {{[string]::IsNullOrWhiteSpace($_)} {'RSJob'} default {$_}} #default to RSJob since this module first assumed this
        $ThisAttempt = Add-JSMJobAttempt -JobName $j.name -JobType $JobType -Attempt $ThisAttemptNo
        #Run the PreJobCommands
        if ([string]::IsNullOrWhiteSpace($j.PreJobCommands) -eq $false)
        {
            $message = "$($j.Name): Found Pre Job Commands."
            Write-Verbose -Message $message
            $message = "$($j.Name): Run Pre Job Commands"
            try
            {
                $OriginalErrorActionPreference = $ErrorActionPreference
                Write-Verbose -Message $message
                $ErrorActionPreference = 'Stop'
                . $($j.PreJobCommands)
                $ErrorActionPreference = $OriginalErrorActionPreference
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 306
            }
            catch
            {
                $ErrorActionPreference = $OriginalErrorActionPreference
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'PreJobCommands'}}))
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 307
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                Add-JSMJobFailure -Name $j.Name -FailureType 'PreJobCommands' -Attempt $ThisAttempt
                continue nextJobToStart
            }
        }
        #Prepare the StartJob Parameters
        $StartJobParams = $j.StartJobParams
        $StartJobParams.Name = $j.Name
        #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartRSJobParameters property)
        if ($j.ArgumentList.count -ge 1)
        {
            $message1 = "$($j.Name): Process Argument List"
            Write-Verbose -Message $message1
            try
            {
                $StartJobParams.ArgumentList = @(
                    foreach ($a in $j.ArgumentList)
                    {
                        $message = "$($j.Name): Get Argument List Variable $a"
                        Write-Verbose -Message $message
                        Get-Variable -Name $a -ValueOnly -ErrorAction Stop
                        Write-Verbose -Message $message
                    }
                )
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message1 -Status $true -EventID 310
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'ProcessArgumentList'}}))
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message1 -Status $false -EventID 311
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                Add-JSMJobFailure -Name $j.Name -FailureType 'ProcessArgumentList' -Attempt $ThisAttempt
                continue nextJobToStart
            }
        }
        #if the job definition calls for splitting the workload among multiple jobs
        if ($j.JobSplit -gt 1)
        {
            $StartJobParams.Throttle = $j.JobSplit
            try
            {
                $message = "$($j.Name): Get Data to Split Source Variable $($j.jobsplitDataVariableName)"
                Write-Verbose -Message $message
                $DataToSplit = Get-Variable -Name $j.JobSplitDataVariableName -ValueOnly -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 314
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'SplitDataSourceRetrieval'}}))
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 315
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                Add-JSMJobFailure -Name $j.Name -FailureType 'SplitDataSourceRetrieval' -Attempt $ThisAttempt
                continue nextJobToStart
            }
            try
            {
                $message = "$($j.Name): Calculate Split Data Ranges for $($j.jobsplitDataVariableName) for $($j.JobSplit) Split Jobs"
                Write-Verbose -Message $message
                $splitGroups = New-SplitArrayRange -inputArray $DataToSplit -parts $j.JobSplit -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 314
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'SplitDataCalculation'}}))
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 315
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                Add-JSMJobFailure -Name $j.Name -FailureType 'SplitDataCalculation' -Attempt $ThisAttempt
                continue nextJobToStart
            }
            $splitjobcount = 0
            $ThisAttemptJobs = @(
                foreach ($split in $splitGroups)
                {
                    $splitjobcount++
                    $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                    try
                    {
                        $message = "$($j.Name): Start Split Job $splitjobcount of $($j.JobSplit)"
                        Write-Verbose -Message $message
                        & $script:jobtypes.$JobType.Commands.StartJob @StartJobParams
                        Write-Verbose -Message $message
                        Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 318
                    }
                    catch
                    {
                        $myerror = $_.tostring()
                        Write-Warning -Message $message
                        Write-Warning -Message $myerror
                        $FailedStartJobs.add($($j | Select-Object -Property *,@{n='FailureType';e={'JobStartWithSplitData'}}))
                        Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 319
                        Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                        Add-JSMJobFailure -Name $j.Name -FailureType 'JobStartWithSplitData' -Attempt $ThisAttempt
                        continue nextJobToStart
                    }
                }
            )
            $SuccessStartJobs.add($j)
        }
        #otherwise just start one job
        else
        {
            try
            {
                $message = "$($j.Name): Start Job"
                Write-Verbose -Message $message
                $ThisAttemptJob = @(& $script:jobtypes.$JobType.Commands.StartJob @StartJobParams)
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 318
                $SuccessStartJobs.add($j)
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs.add($($job | Select-Object -Property *,@{n='FailureType';e={'JobEngineJobStart'}}))
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 319
                Set-JSMJobAttempt -Attempt $ThisAttemptNo -JobName $j.name -StopType Fail
                Add-JSMJobFailure -Name $j.Name -FailureType 'JobEngineJobStart' -Attempt $ThisAttempt
                continue nextJobToStart
            }
        }
        #$j | Add-Member -MemberType NoteProperty -Name StartTime -Value (Get-Date) -Force
    }
    if ($FailedStartJobs.count -ge 1)
    {
        $message = "$($FailedStartJobs.count) Job(s) Failed to Start"
        Write-Verbose -message $message
    }
    $message = "Finished Start-JSMJob"
    Write-Verbose -message $message

    @{
        SuccessStartJobs = $SuccessStartJobs
        FailedStartJobs = $FailedStartJobs
    }
}