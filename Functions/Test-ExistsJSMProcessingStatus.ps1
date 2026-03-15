function Test-ExistsJSMProcessingStatus
{
    <#
    .SYNOPSIS
        Tests whether the JSMProcessingLoopStatus module variable exists.
    .DESCRIPTION
        Returns $true if the script-scoped JSMProcessingLoopStatus variable exists, $false otherwise.
    .OUTPUTS
        [bool]
    .EXAMPLE
        PS C:\> Test-ExistsJSMProcessingStatus

        Returns $true if the processing status variable has been initialized.
    #>
    [CmdletBinding()]
    param ()
    Test-Path 'variable:script:JSMProcessingLoopStatus'
}