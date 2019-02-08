function Remove-JSMJobCompletion
{
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:JobCompletions.Remove($Name)
}