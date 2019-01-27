function Clear-JSMCompletedJob
{
    [cmdletbinding()]
    param(
    )
    $script:CompletedJobs = @{}
}