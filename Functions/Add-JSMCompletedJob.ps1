function Add-JSMCompletedJob
{
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:CompletedJobs.$Name = $true
}