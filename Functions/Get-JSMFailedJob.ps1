function Get-JSMFailedJob
{
    [cmdletbinding()]
    param(
    )
    if ($true -ne (Test-Path variable:Script:FailedJobs))
    {
        $script:FailedJobs = [hashtable]@{}
    }
    $script:FailedJobs
}