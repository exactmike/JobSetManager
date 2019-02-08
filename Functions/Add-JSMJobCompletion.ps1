function Add-JSMJobCompletion
{
    <#
    .SYNOPSIS
        Adds an entry for a completed JSM Job to the JobCompletions module variable
    .DESCRIPTION
        Adds an entry for a successfully completed JSM Job to the JobCompletions module variable which is a hashtable of JobNames with the completed JobAttempt as the value.
    .EXAMPLE
        PS C:\> Add-JSMJobCompletion -Name 'Job1'

        Adds JobCompletion entry to the JobCompletions module variable.
    #>
    [cmdletbinding()]
    param(
        [string]$Name
    )
    $script:JobCompletions.$Name = $true
}