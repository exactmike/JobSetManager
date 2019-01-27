Function Start-JSMStopwatch
{
    [cmdletbinding()]
    param(
        [switch]$Restart
    )
    if ($false -eq (Test-Path variable:Script:Stopwatch) -or $true -eq $Restart)
    {
        $Script:Stopwatch = [system.diagnostics.stopwatch]::startNew()
    }
}