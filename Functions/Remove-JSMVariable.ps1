function Remove-JSMVariable
{
    param
    (
    [string]$Name
    )
    Remove-Variable -Scope Script -Name $name
}
