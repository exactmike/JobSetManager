function Get-JSMStopwatch
{
    <#
    .SYNOPSIS
        Gets the module stopwatch, starting it if it does not already exist.
    .DESCRIPTION
        Returns the script-scoped Stopwatch instance. If the stopwatch variable does not exist,
        calls Start-JSMStopwatch to create and start it first.
    .OUTPUTS
        [System.Diagnostics.Stopwatch]
    .EXAMPLE
        PS C:\> Get-JSMStopwatch

        Returns the running module stopwatch.
    #>
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