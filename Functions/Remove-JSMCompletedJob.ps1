function Remove-JSMCompletedJob
{
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:CompletedJobs.Remove($Name)
}