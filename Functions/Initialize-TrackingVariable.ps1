function Initialize-TrackingVariable
{
    if ($true -ne (Test-Path -Path variable:Script:JobRequired))
    {
      $Script:JobRequired = @()
      $Script:JobRequired = {$Script:JobRequired}.Invoke()
    }
    if ($true -ne (Test-Path variable:Script:JobAttempts))
    {
      $Script:JobAttempts = @()
      $Script:JobAttempts = {$Script:JobAttempts}.Invoke()
    }
    if ($true -ne (Test-Path variable:Script:JSMProcessingLoopStatus))
    {
      $Script:JSMProcessingLoopStatus = @();
      $Script:JSMProcessingLoopStatus = {$Script:JSMProcessingLoopStatus}.Invoke()
    }
    if ($true -ne (Test-Path variable:Script:JobCompletions))
    {
      $script:JobCompletions = @{}
    }
    if ($true -ne (Test-Path variable:Script:JobFailures))
    {
      $Script:JobFailures = @{}
    }
    if ($true -ne (Test-Path variable:Script:JSMProcessingStatusEntryID))
    {
      [int32]$script:JSMProcessingStatusEntryID = 0
    }
}
