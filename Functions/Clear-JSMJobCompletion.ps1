function Clear-JSMJobCompletion
{
    [cmdletbinding()]
    param(
    )
    $script:JobCompletions.clear()
}