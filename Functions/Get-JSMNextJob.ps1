function Get-JSMNextJob
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$CompletedJob
        ,
        [parameter(Mandatory)]
        [hashtable]$CurrentJob
        ,
        [parameter(Mandatory)]
        [hashtable]$FailedJob
        ,
        [parameter(Mandatory)]
        [psobject[]]$RequiredJob
        ,
        [parameter()]
        [int]$JobFailureRetryLimit
    )
    $JobsToStart = @(
        foreach ($j in $RequiredJob)
        {
            $JobFailureRetryLimitForThisJob = [math]::Max($j.JobFailureRetryLimit,$JobFailureRetryLimit)
            if (
                ($j.Name -notin $CompletedJob.Keys) -and
                ($j.Name -notin $CurrentJob.Keys) -and
                ($j.Name -notin $FailedJob.Keys -or $FailedJob.$($j.Name).FailureCount -lt $JobFailureRetryLimitForThisJob) -and
                (
                    ($j.DependsOnJobs.count -eq 0) -or
                    (Test-JSMJobCondition -JobConditionList $j.DependsOnJobs -ConditionValuesObject $CompletedJobs -TestFor $true)
                )
            )
            {
                $j
            }
        }
    )
    $JobsToStart
}