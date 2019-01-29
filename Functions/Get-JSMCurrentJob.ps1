function Get-JSMCurrentJob
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [psobject[]]$RequiredJob
        ,
        [parameter(Mandatory)]
        [hashtable]$CompletedJob
    )
    $CurrentRSJobs = @(Get-RSJob | Where-Object -FilterScript {$_.Name -in $RequiredJob.Name -and $_.Name -notin $CompletedJob.Keys})
    $CurrentJobs = @{}
    $CurrentRSJobs | Select-Object -ExpandProperty Name | Sort-Object -Unique | ForEach-Object {$CurrentJobs.$($_) =  $true}
    $CurrentJobs
}