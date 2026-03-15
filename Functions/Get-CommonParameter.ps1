Function Get-CommonParameter
{
    <#
    .SYNOPSIS
        Returns the names of the common PowerShell parameters.
    .DESCRIPTION
        Uses a SupportsShouldProcess CmdletBinding to enumerate the full set of common parameter
        names from the current function. Used internally to filter common parameters when iterating
        a function's bound parameters.
    .OUTPUTS
        [string[]]
    .EXAMPLE
        PS C:\> Get-CommonParameter

        Returns the names of all common parameters (Verbose, Debug, ErrorAction, etc.).
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess($true))
    {
        $MyInvocation.MyCommand.Parameters.Keys
    }
}
