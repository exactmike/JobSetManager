function Get-JSMJobCompletion
{
    [cmdletbinding()]
    param(
        #add param set for updating completed?
    )
    if ($true -ne (Test-Path variable:Script:JobCompletions))
    {
        Initialize-TrackingVariable
    }
    $script:JobCompletions
}