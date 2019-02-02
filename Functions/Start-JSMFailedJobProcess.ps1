Function Start-JSMFailedJobProcess
{
    [CmdletBinding()]
    param(
        [psobject[]]$NewlyFailedJobs
    )
    $FatalFailure = $false
    foreach ($j in $newlyFailedJobs)
    {
        $FailedJobs = Get-JSMFailedJob
        #if JobFailureRetryLimit exceeded then abort the loop
        $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
        if ($FailedJobs.$($j.name).FailureCount -ge $JobFailureRetryLimitForThisJob)
        {
            $message = "$($j.Name): Exceeded JobFailureRetry Limit. Ending Job Processing Loop. Failure Count: $($FailedJobs.$($j.name).FailureCount). FailureTypes: $($FailedJobs.$($j.name).FailureType -join ',')"
            Write-Warning -Message $message
            Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
            $FatalFailure = $true
        }
        else #otherwise remove the jobs and we'll try again next loop
        {
            try
            {
                $message = "$($j.Name): Removing Failed RSJob(s)."
                Write-Verbose -Message $message
                Get-RSJob -Name $j.name | Remove-RSJob -ErrorAction Stop
                Write-Verbose -Message $message
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $true
            }
            catch
            {
                $myerror = $_.tostring()
                Write-Warning -Message $message
                Write-Warning -Message $myerror
                Add-JSMProcessingLoopStatusEntry -Job $j.name -Message $message -Status $false
            }
        }
    }
    $FatalFailure
}