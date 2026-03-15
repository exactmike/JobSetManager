function Clear-JSMJobCompletion
{
    <#
    .SYNOPSIS
        Clears all entries from the JobCompletions module variable.
    .DESCRIPTION
        Removes all records from the script-scoped JobCompletions hashtable.
    .EXAMPLE
        PS C:\> Clear-JSMJobCompletion

        Removes all job completion records.
    #>
    [cmdletbinding()]
    param(
    )
    $script:JobCompletions.clear()
}