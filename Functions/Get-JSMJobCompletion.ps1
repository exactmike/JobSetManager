function Get-JSMJobCompletion
{
    <#
    .SYNOPSIS
        Gets the JobCompletions module variable.
    .DESCRIPTION
        Returns the script-scoped JobCompletions hashtable, which maps completed job names to their
        completion state. Initializes tracking variables if not already present.
    .OUTPUTS
        [hashtable]
    .EXAMPLE
        PS C:\> Get-JSMJobCompletion

        Returns the hashtable of all completed jobs.
    #>
    [cmdletbinding()]
    param(
        #add param set for updating completed?
    )
    if ($true -ne (Test-Path variable:Script:JobCompletions))
    {
        Initialize-TrackingVariable
    }
    $script:JobCompletions
}