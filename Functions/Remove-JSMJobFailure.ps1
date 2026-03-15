function Remove-JSMJobFailure
{
    <#
    .SYNOPSIS
        Removes a job entry from the JobFailures module variable.
    .DESCRIPTION
        Removes the specified job name key from the script-scoped JobFailures hashtable.
    .PARAMETER Name
        The name of the job to remove from the JobFailures hashtable.
    .EXAMPLE
        PS C:\> Remove-JSMJobFailure -Name 'Job1'

        Removes the Job1 entry from the JobFailures hashtable.
    #>
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:JobFailures.Remove($Name)
}