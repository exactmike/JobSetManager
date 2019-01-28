function Get-JSMCompletedJob
{
    [cmdletbinding()]
    param(
        #add param set for updating completed?
    )
    if ($true -ne (Test-Path variable:Script:CompletedJobs))
    {
        $script:CompletedJobs = [ordered]@{}
    }
    $script:CompletedJobs
}