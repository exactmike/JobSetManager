function Remove-JSMJobCompletion
{
    <#
    .SYNOPSIS
        Removes a job entry from the JobCompletions module variable.
    .DESCRIPTION
        Removes the specified job name key from the script-scoped JobCompletions hashtable.
    .PARAMETER Name
        The name of the job to remove from the JobCompletions hashtable.
    .EXAMPLE
        PS C:\> Remove-JSMJobCompletion -Name 'Job1'

        Removes the Job1 entry from the JobCompletions hashtable.
    #>
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:JobCompletions.Remove($Name)
}