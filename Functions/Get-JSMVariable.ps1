function Get-JSMVariable
{
    param
    (
    [string]$Name
    )
        Get-Variable -Scope Script -Name $name
}
