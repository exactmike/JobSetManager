function Get-JSMJobFailure
{
    <#
    .SYNOPSIS
        Gets the JobFailures module variable.
    .DESCRIPTION
        Returns the script-scoped JobFailures hashtable, which maps failed job names to their
        failure records. Initializes tracking variables if not already present.
    .OUTPUTS
        [hashtable]
    .EXAMPLE
        PS C:\> Get-JSMJobFailure

        Returns the hashtable of all jobs with failure records.
    #>
    [cmdletbinding()]
    param(
    )
    if ($true -ne (Test-Path variable:Script:JobFailures))
    {
        Initialize-TrackingVariable
    }
    $script:JobFailures
}