function Add-JSMProcessingStatusEntry
{
  <#
  .SYNOPSIS
    Adds an entry to the JSMProcessingLoopStatus array (script scope variable).
  .DESCRIPTION
    Adds an entry to the JSMProcessingLoopStatus array, a script scope variable, for the purpose of tracking/logging events

    The entry is structured in the sense that it includes attributes for JobName, Message, and Status and automatically adds a TimeStamp

  .EXAMPLE
    PS C:\> Add-JSMProcessingStatusEntry -JobName GetUsers -Message 'Ready to start' -Status $true -PassThru

    Creates an custom PSObject entry in JSMProcessingLoopStatus with JobName = 'GetUsers', Message = 'Ready to start', and status = $true, timestamp = current time.  -Passthru also causes the entry to be sent to standard output.
  .NOTES
        Website: https://github.com/exactmike/JobSetManager
        Copyright: (c) 2019 by Mike Campbell, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT
  #>
    [cmdletbinding()]
    param
    (
      [parameter()]
      [alias('Job')]
      [string]$JobName
      ,
      [parameter()]
      [string]$Message
      ,
      [parameter()]
      [bool]$Status
      ,
      # EventID From predefined list of EventIDs.
      [Parameter(Mandatory)]
      [Int]
      $EventID
      ,
      [parameter()]
      [switch]$PassThru
    )
    if ($false -eq (Test-ExistsJSMProcessingStatus))
    {
      $script:JSMProcessingLoopStatus = @(); $script:JSMProcessingLoopStatus = {$script:JSMProcessingLoopStatus}.Invoke()
      [int32]$script:JSMProcessingStatusEntryID = 0
    }
    $script:JSMProcessingStatusEntryID++
    $Entry = [pscustomobject]@{
      EntryID = $script:JSMProcessingStatusEntryID;
      TimeStamp = Get-Date
      JobName = $JobName;
      Message = $Message;
      Status = $Status
      EventID = $EventID
    }
    $null = $script:JSMProcessingLoopStatus.add($Entry)
    if ($true -eq $PassThru)
    {
      $Entry
    }
}
