function Remove-JSMJobFailure
{
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:JobFailures.Remove($Name)
}