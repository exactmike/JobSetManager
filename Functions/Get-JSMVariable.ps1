function Get-JFMVariable
{
    param
    (
    [string]$Name
    )
        Get-Variable -Scope Script -Name $name
}
