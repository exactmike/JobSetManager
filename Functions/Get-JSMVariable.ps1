function Get-JSMVariable
{
    <#
    .SYNOPSIS
        Gets a script-scoped module variable object.
    .DESCRIPTION
        Retrieves a variable object from the module script scope by name.
        Returns the full variable object (name and value).
    .PARAMETER Name
        The name of the script-scoped variable to retrieve.
    .OUTPUTS
        [System.Management.Automation.PSVariable]
    .EXAMPLE
        PS C:\> Get-JSMVariable -Name 'JobAttempts'

        Returns the JobAttempts script-scoped variable object.
    #>
    param
    (
    [string]$Name
    )
        Get-Variable -Scope Script -Name $name
}
