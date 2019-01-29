function Get-JSMStopwatch
{
    [cmdletbinding()]
    param(
    )
    if ($true -eq (Test-Path variable:Script:Stopwatch))
    {
        $script:Stopwatch
    }
    else
    {
        Start-JSMStopwatch
        $script:Stopwatch
    }
}