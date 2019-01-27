function Remove-JSMFailedJob
{
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:FaileJobs.Remove($Name)
}