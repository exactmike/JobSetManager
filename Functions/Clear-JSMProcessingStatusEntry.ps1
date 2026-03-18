function Clear-JSMProcessingStatusEntry
{
    <#
    .SYNOPSIS
        Clears entries from the JSMProcessingLoopStatus module variable.
    .DESCRIPTION
        Removes status log entries from the script-scoped JSMProcessingLoopStatus collection.
        With no parameters, clears all entries and resets the entry ID counter to zero.
        With -JobName, clears all entries for that job. With -EntryID, clears the specified
        entries by ID.
    .PARAMETER JobName
        The name of the job whose status entries should be removed.
    .PARAMETER EntryID
        One or more entry IDs to remove.
    .EXAMPLE
        PS C:\> Clear-JSMProcessingStatusEntry

        Removes all processing status log entries and resets the ID counter.
    .EXAMPLE
        PS C:\> Clear-JSMProcessingStatusEntry -JobName 'Job1'

        Removes all status log entries for Job1.
    .EXAMPLE
        PS C:\> Clear-JSMProcessingStatusEntry -EntryID 3,7

        Removes the status log entries with EntryIDs 3 and 7.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'JobName', Justification = 'Used inside Where() scriptblock closure')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'EntryID', Justification = 'Used inside Where() scriptblock closure')]
    [cmdletbinding(DefaultParameterSetName = 'All')]
    param(
        [parameter(ParameterSetName = 'SpecificJob',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$JobName
        ,
        [parameter(ParameterSetName = 'SpecificEntryID',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [int32[]]$EntryID
    )
    Begin
    {
        Initialize-TrackingVariable
        switch ($PSCmdlet.ParameterSetName)
        {
            'All'
            {
                [int32]$script:JSMProcessingStatusEntryID = 0
                $script:JSMProcessingLoopStatus.clear()
            }
        }
    }
    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'SpecificJob'
            {
                $toRemove = $script:JSMProcessingLoopStatus.where({ $_.JobName -eq $JobName })
                foreach ($item in $toRemove)
                {
                    $script:JSMProcessingLoopStatus.Remove($item)
                }
            }
            'SpecificEntryID'
            {
                $toRemove = $script:JSMProcessingLoopStatus.where({ $_.EntryID -in $EntryID })
                foreach ($item in $toRemove)
                {
                    $script:JSMProcessingLoopStatus.Remove($item)
                }
            }
        }
    }
}
