Function Start-JSMJob
{
    <#
    .SYNOPSIS
        Starts one or more JobSetManager-defined jobs using native PowerShell job engines.
    .DESCRIPTION
        Starts jobs defined as PSCustomObjects using Start-Job or Start-ThreadJob. Handles
        pre-job commands, argument list resolution, FunctionsToLoad/ModulesToImport conversion
        to InitializationScript, and split-job tracking via $script:SplitJobGroups. Records
        a job attempt entry for each job started.
    .PARAMETER Job
        One or more job definition objects (PSCustomObject) to start.
    .PARAMETER JobType
        The job engine to use. PSJob uses Start-Job; ThreadJob uses Start-ThreadJob.
        Defaults to PSJob. Invoke-JSMProcessingLoop auto-detects and passes this value.
    .EXAMPLE
        PS C:\> Start-JSMJob -Job $jobDefinitions -JobType PSJob

        Starts each job definition using Start-Job.
    .OUTPUTS
        [hashtable] with keys SuccessStartJobs and FailedStartJobs.
    #>
    [CmdletBinding()]
    param(
        [psobject[]]$Job
        ,
        [ValidateSet('PSJob','ThreadJob')]
        [string]$JobType = 'PSJob'
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
        #Prepare the Start-Job Parameters
        $StartJobParams = $j.StartJobParams.Clone()
        $StartJobParams.Name = $j.Name
        #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartJobParameters property)
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
        #Build InitializationScript from FunctionsToLoad and ModulesToImport
        $initParts = @()
        if ($StartJobParams.ContainsKey('FunctionsToLoad') -and $StartJobParams.FunctionsToLoad.Count -gt 0)
        {
            foreach ($func in $StartJobParams.FunctionsToLoad)
            {
                $funcCmd = Get-Command $func -ErrorAction SilentlyContinue
                if ($null -ne $funcCmd)
                {
                    $initParts += "function $func {`n$($funcCmd.ScriptBlock)`n}"
                }
            }
            $StartJobParams.Remove('FunctionsToLoad')
        }
        if ($StartJobParams.ContainsKey('ModulesToImport') -and $StartJobParams.ModulesToImport.Count -gt 0)
        {
            foreach ($mod in $StartJobParams.ModulesToImport)
            {
                $initParts += "Import-Module '$mod' -ErrorAction Stop"
            }
            $StartJobParams.Remove('ModulesToImport')
        }
        if ($StartJobParams.ContainsKey('PSSnapinsToImport'))
        {
            $StartJobParams.Remove('PSSnapinsToImport')
        }
        if ($initParts.Count -gt 0)
        {
            $StartJobParams.InitializationScript = [scriptblock]::Create($initParts -join "`n")
        }
        #Extract ThrottleLimit if specified (used for ThreadJob split jobs)
        $ThrottleLimit = $j.JobSplit
        if ($StartJobParams.ContainsKey('Throttle'))
        {
            $ThrottleLimit = $StartJobParams.Throttle
            $StartJobParams.Remove('Throttle')
        }
        #if the job definition calls for splitting the workload among multiple jobs
        if ($j.JobSplit -gt 1)
        {
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
            $subJobNames = [System.Collections.Generic.List[string]]::new()
            foreach ($split in $splitGroups)
            {
                $splitjobcount++
                $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                $SplitJobName = "$($j.Name)_JSMPart_$splitjobcount"
                $subJobNames.Add($SplitJobName)
                $SplitStartJobParams = $StartJobParams.Clone()
                $SplitStartJobParams.Name = $SplitJobName
                try
                {
                    $message = "$($j.Name): Start Split Job $splitjobcount of $($j.JobSplit) as $SplitJobName"
                    Write-Verbose -Message $message
                    switch ($JobType)
                    {
                        'ThreadJob'
                        {
                            Start-ThreadJob @SplitStartJobParams -ThrottleLimit $ThrottleLimit | Out-Null
                        }
                        default
                        {
                            Start-Job @SplitStartJobParams | Out-Null
                        }
                    }
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
            $script:SplitJobGroups[$j.Name] = @($subJobNames)
            $SuccessStartJobs.add($j)
        }
        #otherwise just start one job
        else
        {
            try
            {
                $message = "$($j.Name): Start Job"
                Write-Verbose -Message $message
                switch ($JobType)
                {
                    'ThreadJob'
                    {
                        Start-ThreadJob @StartJobParams | Out-Null
                    }
                    default
                    {
                        Start-Job @StartJobParams | Out-Null
                    }
                }
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
