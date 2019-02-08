function Get-JSMJobNext
{
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
        [psobject[]]$JobRequired
        ,
        [parameter()]
        [int]$JobFailureRetryLimit
    )
    $JobsToStart = @(
        foreach ($j in $RequiredJob)
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