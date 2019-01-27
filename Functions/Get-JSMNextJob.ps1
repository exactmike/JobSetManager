function Get-JSMNextJob
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$CompletedJobs
        ,
        [parameter()]
        [hashtable]$CurrentJobs
        ,
        [parameter(Mandatory)]
        [psobject[]]$RequiredJobs
    )
    $JobsToStart = @(
        $RequiredJobs | Where-Object -FilterScript {
            ($_.Name -notin $CompletedJobs.Keys) -and
            ($_.Name -notin $CurrentJobs.Keys) -and
            (
                ($_.DependsOnJobs.count -eq 0) -or
                (Test-JSMJobCondition -JobConditionList $_.DependsOnJobs -ConditionValuesObject $CompletedJobs -TestFor $true)
            )
        }
    )
    $JobsToStart
}
