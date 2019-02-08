Function Start-JSMJobFailureProcess
{
    [CmdletBinding()]
    param(
        [psobject[]]$NewJobFailure
    )
    $FatalFailure = $false
    foreach ($j in $NewJobFailure)
    {
        $FailedJobs = Get-JSMJobFailure
        #if JobFailureRetryLimit exceeded then abort the loop
        $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
        if ($FailedJobs.$($j.name).FailureCount -ge $JobFailureRetryLimitForThisJob)
        {
            $message = "Exceeded JobFailureRetry Limit. Ending Job Processing Loop. Failure Count: $($FailedJobs.$($j.name).FailureCount). FailureTypes: $($FailedJobs.$($j.name).FailureType -join ',')"
            Write-Warning -Message $message
            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 507
            Add-JSMProcessingStatusEntry -Job $j.name -Message "Failed Job Fatal Failure" -Status $false -EventID 599
            $FatalFailure = $true
        }
        else #otherwise remove the jobs and we'll try again next loop
        {
            $message ="$($j.Name): JobFailureRetry Limit Not Exceeded. Failure Count: $($FailedJobs.$($j.name).FailureCount). FailureTypes: $($FailedJobs.$($j.name).FailureType -join ',')"
            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 506
            try
            {
                $message = "$($j.Name): Removing Failed RSJob(s)."
                Write-Verbose -Message $message
                Get-RSJob -Name $j.name | Remove-RSJob -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $true -EventID 510
                Add-JSMProcessingStatusEntry -Job $j.name -Message "Failed Job May Re-Attempt" -Status $true -EventID 510
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 511
                Add-JSMProcessingStatusEntry -Job $j.name -Message "Failed Job Fatal Failure" -Status $false -EventID 599
                $FatalFailure = $true
            }
        }
    }
    $FatalFailure
}