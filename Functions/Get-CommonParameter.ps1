Function Get-CommonParameter
{
    [cmdletbinding(SupportsShouldProcess)]
    param()
    if ($PSCmdlet.ShouldProcess())
    {
        $MyInvocation.MyCommand.Parameters.Keys
    }
}
