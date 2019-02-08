function Clear-JSMJobFailure
{
    [cmdletbinding()]
    param(
    )
    $script:JobFailures.clear()
}