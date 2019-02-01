function Test-JSMProcessingLoopStatusExists
{
    [CmdletBinding()]
    param ()
    Test-Path 'variable:script:JSMProcessingLoopStatus'
}