    Function Get-CommonParameter
    {

    [cmdletbinding(SupportsShouldProcess)]
    param()
    $MyInvocation.MyCommand.Parameters.Keys

    }
