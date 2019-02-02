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
        Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
    }
    $FailedStartJobs = @()
    #Start the jobs
    :nextJobToStart foreach ($j in $Job)
    {
        #Run the PreJobCommands
        if ([string]::IsNullOrWhiteSpace($j.PreJobCommands) -eq $false)
        {
            $message = "$($j.Name): Found PreJobCommands."
            Write-Verbose -Message $message
            $message = "$($j.Name): Run PreJobCommands"
            try
            {
                Write-Verbose -Message $message
                . $($j.PreJobCommands)
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'PreJobCommands'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'PreJobCommands'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                continue nextJobToStart
            }
        }
        #Prepare the Start-RSJob Parameters
        $StartRSJobParams = $j.StartRSJobParams
        $StartRSJobParams.Name = $j.Name
        #add values for variable names listed in the argumentlist property of the Defined Job (if it is not already in the StartRSJobParameters property)
        if ($j.ArgumentList.count -ge 1)
        {
            $message = "$($j.Name): Found ArgumentList to populate with live variables."
            Write-Verbose -Message $message
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
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'ArgumentListProcessing'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'ArgumentListProcessing'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
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
                $message = "$($j.Name): Get the data to split from variable $($j.jobsplitDataVariableName)"
                Write-Verbose -Message $message
                $DataToSplit = Get-Variable -Name $j.JobSplitDataVariableName -ValueOnly -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'RetrievingSplitData'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'RetrievingSplitData'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                continue nextJobToStart
            }
            try
            {
                $message = "$($j.Name): Calculate the split ranges for the data $($j.jobsplitDataVariableName) for $($j.JobSplit) batch jobs"
                Write-Verbose -Message $message
                $splitGroups = New-SplitArrayRange -inputArray $DataToSplit -parts $j.JobSplit -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'SplitDataCalculation'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'SplitDataCalculation'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                continue nextJobToStart
            }
            $splitjobcount = 0
            foreach ($split in $splitGroups)
            {
                $splitjobcount++
                $YourSplitData = $DataToSplit[$($split.start)..$($split.end)]
                try
                {
                    $message = "$($j.Name): Start Batch Job $splitjobcount of $($j.JobSplit)"
                    Write-Verbose -Message $message
                    Start-RSJob @StartRSJobParams | Out-Null
                    Write-Verbose -Message $message
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
                }
                catch
                {
                    $myerror = $_.tostring()
                    Write-Warning -Message $message
                    Write-Warning -Message $myerror
                    $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'JobStartWithSplitData'}})
                    Add-JSMFailedJob -Name $j.Name -FailureType 'JobStartWithSplitData'
                    Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
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
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                $FailedStartJobs += $($job | Select-Object -Property *,@{n='FailureType';e={'JobStart'}})
                Add-JSMFailedJob -Name $j.Name -FailureType 'JobStart'
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
                continue nextJobToStart
            }
        }
        $j | Add-Member -MemberType NoteProperty -Name StartTime -Value (Get-Date) -Force
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