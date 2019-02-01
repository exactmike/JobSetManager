function Get-JSMProcessingLoopStatusEntry
{
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
        if (-not $(Test-JSMProcessingLoopStatusExists))
        {
            throw('JSMProcessingLoopStatus is not initialized')
        }
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