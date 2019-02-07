function Test-ExistsJSMProcessingStatus
{
    [CmdletBinding()]
    param ()
    Test-Path 'variable:script:JSMProcessingLoopStatus'
}