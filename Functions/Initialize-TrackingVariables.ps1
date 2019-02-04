function Initialize-TrackingVariables
{
    if ($true -ne (Test-Path variable:Script:JobAttempts))
    {
        $script:JobAttempts = @()
        $script:JobAttempts = {$script:JobAttempts}.Invoke()
    }
}
