Function Start-JSMStopwatch
{
    <#
    .SYNOPSIS
        Starts the module stopwatch, optionally restarting it if already running.
    .DESCRIPTION
        Creates and starts a new System.Diagnostics.Stopwatch in the module script scope.
        If the stopwatch variable already exists, it is only restarted when -Restart is specified.
    .PARAMETER Restart
        When specified, restarts the stopwatch even if it is already running.
    .EXAMPLE
        PS C:\> Start-JSMStopwatch

        Starts the module stopwatch if it is not already running.
    .EXAMPLE
        PS C:\> Start-JSMStopwatch -Restart

        Restarts the module stopwatch regardless of its current state.
    #>
    [cmdletbinding()]
    param(
        [switch]$Restart
    )
    if ($false -eq (Test-Path variable:Script:Stopwatch) -or $true -eq $Restart)
    {
        $Script:Stopwatch = [system.diagnostics.stopwatch]::startNew()
    }
}