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
    $CurrentRSJobs = @(Get-RSJob | Where-Object -FilterScript {$_.Name -in $JobRequired.Name -and $_.Name -notin $JobCompletion.Keys})
    $CurrentJobs = @{}
    $CurrentRSJobs | Select-Object -ExpandProperty Name | Sort-Object -Unique | ForEach-Object {$CurrentJobs.$($_) =  $true}
    $CurrentJobs
}