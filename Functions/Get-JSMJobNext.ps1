function Get-JSMJobNext
{
    <#
    .SYNOPSIS
        Returns job definitions that are eligible to start on the next loop iteration.
    .DESCRIPTION
        Evaluates each required job against the current completion, running, and failure state.
        A job is eligible if: it is not yet completed, not currently running, has not exceeded
        the retry limit, and all jobs it depends on are completed.
    .PARAMETER JobCompletion
        Hashtable of completed job names (keys).
    .PARAMETER JobCurrent
        Hashtable of currently running job names (keys).
    .PARAMETER JobFailure
        Hashtable of job names with failure records (values have a FailureCount property).
    .PARAMETER JobRequired
        The full list of job definition objects for this job set.
    .PARAMETER JobFailureRetryLimit
        Global retry limit. Per-job limit is compared and the higher value applies.
    .EXAMPLE
        PS C:\> Get-JSMJobNext -JobCompletion $completions -JobCurrent $current -JobRequired $jobs -JobFailure $failures -JobFailureRetryLimit 3

        Returns job definitions ready to start.
    .OUTPUTS
        [pscustomobject[]] job definitions eligible for starting.
    #>
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$JobCompletion
        ,
        [parameter(Mandatory)]
        [hashtable]$JobCurrent
        ,
        [parameter(Mandatory)]
        [hashtable]$JobFailure
        ,
        [parameter(Mandatory)]
        [hashtable]$JobRequired
        ,
        [parameter()]
        [int]$JobFailureRetryLimit
    )
    $JobsToStart = @(
        foreach ($j in $JobRequired.Values)
        {
            $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
            if (
                ($j.Name -notin $JobCompletion.Keys) -and
                ($j.Name -notin $JobCurrent.Keys) -and
                ($j.Name -notin $JobFailure.Keys -or $JobFailure.$($j.Name).FailureCount -lt $JobFailureRetryLimitForThisJob) -and
                (
                    ($j.DependsOnJobs.count -eq 0) -or
                    (Test-JSMJobCondition -JobConditionList $j.DependsOnJobs -ConditionValuesObject $JobCompletion -TestFor $true)
                )
            )
            {
                $j
            }
        }
    )
    $JobsToStart
}