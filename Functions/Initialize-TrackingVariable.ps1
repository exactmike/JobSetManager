function Initialize-TrackingVariable
{
    if ($true -ne (Test-Path variable:Script:JobAttempts))
    {
        $script:JobAttempts = @()
        $script:JobAttempts = {$script:JobAttempts}.Invoke()
    }
    if ($true -ne (Test-ExistsJSMProcessingStatus))
    {
      $script:JSMProcessingLoopStatus = @(); $script:JSMProcessingLoopStatus = {$script:JSMProcessingLoopStatus}.Invoke()
      [int32]$script:JSMProcessingStatusEntryID = 0
    }
}
