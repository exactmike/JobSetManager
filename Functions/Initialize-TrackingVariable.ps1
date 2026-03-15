function Initialize-TrackingVariable
{
    <#
    .SYNOPSIS
        Initializes module script-scope tracking variables if they do not already exist.
    .DESCRIPTION
        Idempotently creates the script-scoped variables used by JobSetManager: JobAttempts,
        JSMProcessingLoopStatus, JSMProcessingStatusEntryID, JobCompletions, JobFailures,
        and SplitJobGroups. Existing variables are not reset.
    .EXAMPLE
        PS C:\> Initialize-TrackingVariable

        Ensures all required module tracking variables exist without resetting any existing state.
    #>
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
    if ($true -ne (Test-Path variable:Script:JobCompletions))
    {
      $script:JobCompletions = @{}
    }
    if ($true -ne (Test-Path variable:Script:JobFailures))
    {
      $script:JobFailures = @{}
    }
    if ($true -ne (Test-Path variable:Script:SplitJobGroups))
    {
      $script:SplitJobGroups = @{}
    }
}
