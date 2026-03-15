Function Start-JSMJobFailureProcess
{
    <#
    .SYNOPSIS
        Handles failed jobs - either removes them for retry or escalates to fatal failure.
    .DESCRIPTION
        For each failed job, compares the failure count against the retry limit. If the limit
        is exceeded, marks the situation as a fatal failure. Otherwise, removes the underlying
        PS job (and split sub-jobs if applicable) so the job can be retried on the next loop
        iteration.
    .PARAMETER NewJobFailure
        One or more job failure objects, each being a job definition with an added FailureType property.
    .PARAMETER JobFailureRetryLimit
        The global retry limit. Per-job limits are compared against this and the higher value applies.
    .EXAMPLE
        PS C:\> Start-JSMJobFailureProcess -NewJobFailure $failures -JobFailureRetryLimit 3

        Processes failures. Returns $true if any failure was fatal, $false otherwise.
    .OUTPUTS
        [bool] $true if a fatal failure occurred, $false if all failures are retryable.
    #>
    [CmdletBinding()]
    param(
        [psobject[]]$NewJobFailure
        ,
        $JobFailureRetryLimit
    )
    $FatalFailure = $false
    foreach ($j in $NewJobFailure)
    {
        $JobAttemptFailure = @(Get-JSMJobAttempt -JobName $j.Name | Where-Object -filterscript {$_.StopType -ne 'None'})
        #if JobFailureRetryLimit exceeded then abort the loop
        $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
        if ($JobAttemptFailure.count -ge $JobFailureRetryLimitForThisJob)
        {
            $JobFailure = $(Get-JSMJobFailure).$($j.Name)
            $message = "Exceeded JobFailureRetry Limit. Ending Job Processing Loop. Failure Count: $($JobAttemptFailure.count). FailureTypes: $($JobFailure.FailureType -join ',')"
            Write-Warning -Message $message
            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 507
            Add-JSMProcessingStatusEntry -Job $j.name -Message "Failed Job Fatal Failure" -Status $false -EventID 599
            $FatalFailure = $true
        }
        else #otherwise remove the jobs and we'll try again next loop
        {
            $message ="$($j.Name): JobFailureRetry Limit Not Exceeded. Failure Count: $($JobAttemptFailure.count). FailureTypes: $($JobFailure.FailureType -join ',')"
            Add-JSMProcessingStatusEntry -Job $j.name -Message $message -Status $false -EventID 506
            try
            {
                $message = "$($j.Name): Removing Failed Job(s)."
                Write-Verbose -Message $message
                # Remove regular job or split sub-jobs
                if ($null -ne $script:SplitJobGroups -and $script:SplitJobGroups.ContainsKey($j.Name))
                {
                    $subJobNames = $script:SplitJobGroups[$j.Name]
                    Get-Job | Where-Object { $_.Name -in $subJobNames } | Remove-Job -ErrorAction Stop
                    $script:SplitJobGroups.Remove($j.Name)
                }
                else
                {
                    Get-Job -Name $j.Name -ErrorAction SilentlyContinue | Remove-Job -ErrorAction Stop
                }
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
