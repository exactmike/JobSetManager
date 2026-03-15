function Clear-JSMJobFailure
{
    <#
    .SYNOPSIS
        Clears all entries from the JobFailures module variable.
    .DESCRIPTION
        Removes all records from the script-scoped JobFailures hashtable.
    .EXAMPLE
        PS C:\> Clear-JSMJobFailure

        Removes all job failure records.
    #>
    [cmdletbinding()]
    param(
    )
    $script:JobFailures.clear()
}