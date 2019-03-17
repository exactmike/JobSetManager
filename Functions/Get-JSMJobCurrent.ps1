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
    $CurrentJobs = @{}
    $JobsPossiblyCurrent = $JobRequired | Where-Object -FilterScript {$_.Name -notin $JobCompletion.Keys}
    $CurrentJFJobs = @(
        foreach ($jpc in $JobsPossiblyCurrent)
        {
            $JobType = switch ($jpc.JobType) {{[string]::IsNullOrWhiteSpace($_)} {'RSJob'} default {$_}} #default to RSJob since this module first assumed this
            $GetJobCommand = $script:JobTypes.where({$_.Name -eq $JobType}).commands.where({$_.Type -eq 'GetJob'}).Name
            $GetJobParams = @{
                ErrorAction = 'SilentlyContinue'
                Name = $jpc.Name
            }
            &$GetJobCommand @GetJobParams
        }
    )
    $CurrentJFJobs | Select-Object -ExpandProperty Name | Sort-Object -Unique | ForEach-Object {$CurrentJobs.$($_) =  $true}
    $CurrentJobs
}