function Get-JSMProcessingStatusEntry
{
    <#
    .SYNOPSIS
        Gets entries from the module scope array variablle JSMProcessingLoopStatus
    .DESCRIPTION
        Gets all entries or specified entries (by JobName or EntryID) from the module scope array variable JSMProcessingLoopStatus
    .EXAMPLE
        PS C:\> Get-JSMProcessingStatusEntry

        Gets all entries from the JSMProcessingLoopStatus module array variable.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param
    (
        # EntryID of Entry you want to retrieve
        [Parameter(Mandatory, ParameterSetName = 'EntryID', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int32[]]
        $EntryID
        ,
        # JobName of Job entries that you want to retrieve
        [Parameter(Mandatory, ParameterSetName = 'JobName', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]
        $JobName
    )

    begin
    {
        Initialize-TrackingVariable
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'EntryID'
            {
                foreach ($i in $EntryID)
                {
                    $script:JSMProcessingLoopStatus.where( {$_.EntryID -eq $i})
                }
            }
            'All'
            {
                $script:JSMProcessingLoopStatus
            }
            'JobName'
            {
                foreach ($j in $JobName)
                {
                    $script:JSMProcessingLoopStatus.where({$_.JobName -like $j})
                }
            }
        }
    }

    end
    {
    }
}