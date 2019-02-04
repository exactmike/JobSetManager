Function Start-JSMJob
{
    [CmdletBinding()]
    param(
        [psobject[]]$Job
    )
    foreach ($j in $Job)
    {
        $message = "$($j.Name): Ready to Start"
        Write-Verbose -message $message
        Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 302
    }
    $FailedStartJobs = @()
    #Start the jobs
    :nextJobToStart foreach ($j in $Job)
    {
        $PreviousAttempts = @(Get-JSMJobAttempt -JobName $j.name)
        $ThisAttempt = $($($PreviousAttempts.Attempt | Measure-Object -Maximum).Maximum + 1)
        Add-JSMJobAttempt -JobName $j.name -JobType RSJob -Attempt $ThisAttempt
        #Run the PreJobCommands
        if ([string]::IsNullOrWhiteSpace($j.PreJobCommands) -eq $false)
        {
            $message = "$($j.Name): Found Pre Job Commands."
            Write-Verbose -Message $message
            $message = "$($j.Name): Run Pre Job Commands"
            try
            {

                Write-Verbose -Message $message
                . $($j.PreJobCommands)
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 306


            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'PreJobCommands'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'PreJobCommands'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 307
                continue nextJobToStart
            }
        }
        #Prepare the Start-RSJob Parameters
        $StartRSJobParams = $j.StartRSJobParams
        $StartRSJobParams.Name = $j.Name
        #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartRSJobParameters property)
        if ($j.ArgumentList.count -ge 1)
        {
            $message1 = "$($j.Name): Process Argument List"
            Write-Verbose -Message $message1
            try
            {
                $StartRSJobParams.ArgumentList = @(
                    foreach ($a in $j.ArgumentList)
                    {
                        $message = "$($j.Name): Get Argument List Variable $a"
                        Write-Verbose -Message $message
                        Get-Variable -Name $a -ValueOnly -ErrorAction Stop
                        Write-Verbose -Message $message
                    }
                )
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message1 -Status $true -EventID 310
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'ProcessArgumentList'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'ProcessArgumentList'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message1 -Status $false -EventID 311
                continue nextJobToStart
            }
        }
        #if the job definition calls for splitting the workload among multiple jobs
        if ($j.JobSplit -gt 1)
        {
            $StartRSJobParams.Throttle = $j.JobSplit
            $StartRSJobParams.Batch = $j.Name
            try
            {
                $message = "$($j.Name): Get Data to Split Source Variable $($j.jobsplitDataVariableName)"
                Write-Verbose -Message $message
                $DataToSplit = Get-Variable -Name $j.JobSplitDataVariableName -ValueOnly -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 314
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'SplitDataSourceRetrieval'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'SplitDataSourceRetrieval'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 315
                continue nextJobToStart
            }
            try
            {
                $message = "$($j.Name): Calculate Split Data Ranges for $($j.jobsplitDataVariableName) for $($j.JobSplit) Split Jobs"
                Write-Verbose -Message $message
                $splitGroups = New-SplitArrayRange -inputArray $DataToSplit -parts $j.JobSplit -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 314
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'SplitDataCalculation'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'SplitDataCalculation'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 315
                continue nextJobToStart
            }
            $splitjobcount = 0
            foreach ($split in $splitGroups)
            {
                $splitjobcount++
                $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                try
                {
                    $message = "$($j.Name): Start Split Job $splitjobcount of $($j.JobSplit)"
                    Write-Verbose -Message $message
                    Start-RSJob @StartRSJobParams | Out-Null
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 318
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'JobStartWithSplitData'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'JobStartWithSplitData'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 319
                    continue nextJobToStart
                }
            }
        }
        #otherwise just start one job
        else
        {
            try
            {
                $message = "$($j.Name): Start Job"
                Write-Verbose -Message $message
                Start-RSJob @StartRSJobParams | Out-Null
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true -EventID 318
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'JobStart'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'JobStart'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false -EventID 319
                continue nextJobToStart
            }
        }
        #$j | Add-Member -MemberType NoteProperty -Name StartTime -Value (Get-Date) -Force
    }
    if ($FailedStartJobs.count -ge 1)
    {
        $message = "$($FailedStartJobs.count) Job(s) Failed to Start"
        Write-Verbose -message $message
        $FailedStartJobs
    }
    $message = "Finished Start-JSMJob"
    Write-Verbose -message $message
}