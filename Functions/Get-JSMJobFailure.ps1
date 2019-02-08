function Get-JSMJobFailure
{
    [cmdletbinding()]
    param(
    )
    if ($true -ne (Test-Path variable:Script:JobFailures))
    {
        Initialize-TrackingVariable
    }
    $script:JobFailures
}