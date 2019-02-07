function Clear-JSMProcessingStatusEntry
{
    [cmdletbinding(DefaultParameterSetName = 'All')]
    param(
        <#
        [parameter(ParameterSetName = 'SpecificJobAttempt',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$JobName
        ,
        [parameter(ParameterSetName = 'SpecificJobAttempt',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [int[]]$Attempt
        #>
        )
    Begin
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'All'
            {
                Initialize-TrackingVariable
                [int32]$script:JSMProcessingStatusEntryID = 0
                $script:JSMProcessingLoopStatus.clear()
            }
        }
    }
    <#
    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'SpecificJobName'
            {
                $Script:
            }
        }
    }
    #>
}