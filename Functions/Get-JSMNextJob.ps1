function Get-JFMNextJob
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$CompletedJobs
        ,
        [parameter()]
        [psobject[]]$AllCurrentJobs
        ,
        [parameter(Mandatory)]
        [psobject[]]$RequiredJobs
    )
    $JobsToStart = @(
        $RequiredJobs | Where-Object -FilterScript {
            ($_.Name -notin $CompletedJobs.Keys) -and
            ($_.Name -notin $AllCurrentJobs.Name) -and
            (
                ($_.DependsOnJobs.count -eq 0) -or
                (Test-JobCondition -JobConditionList $_.DependsOnJobs -ConditionValuesObject $CompletedJobs -TestFor $true)
            )
        }
    )
    Write-Output -InputObject $JobsToStart
}
