function Remove-JFMVariable
{
    param
    (
    [string]$Name
    )
    Remove-Variable -Scope Script -Name $name
}
