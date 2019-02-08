function Get-JSMJobCurrent
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [psobject[]]$JobRequired
        ,
        [parameter(Mandatory)]
        [hashtable]$JobCompletion
    )
    $CurrentRSJobs = @(Get-RSJob | Where-Object -FilterScript {$_.Name -in $RequiredJob.Name -and $_.Name -notin $JobCompletion.Keys})
    $CurrentJobs = @{}
    $CurrentRSJobs | Select-Object -ExpandProperty Name | Sort-Object -Unique | ForEach-Object {$CurrentJobs.$($_) =  $true}
    $CurrentJobs
}