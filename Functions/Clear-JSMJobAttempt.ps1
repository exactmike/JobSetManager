function Clear-JSMJobAttempt
{
    <#
    .SYNOPSIS
        Clears all entries from the JobAttempts module variable.
    .DESCRIPTION
        Removes all job attempt records from the script-scoped JobAttempts collection.
        Initializes tracking variables first if they do not already exist.
    .EXAMPLE
        PS C:\> Clear-JSMJobAttempt

        Removes all job attempt records.
    #>
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
                $script:JobAttempts.clear()
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