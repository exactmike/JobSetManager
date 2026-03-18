function Clear-JSMJobAttempt
{
    <#
    .SYNOPSIS
        Clears job attempt entries from the JobAttempts module variable.
    .DESCRIPTION
        Removes job attempt records from the script-scoped JobAttempts collection.
        With no parameters, clears all records. With -JobName only, clears all attempts
        for that job. With -JobName and -Attempt, clears only the specified attempt
        numbers for that job.
    .PARAMETER JobName
        The name of the job whose attempt records should be removed.
    .PARAMETER Attempt
        One or more attempt numbers to remove for the specified job.
    .EXAMPLE
        PS C:\> Clear-JSMJobAttempt

        Removes all job attempt records.
    .EXAMPLE
        PS C:\> Clear-JSMJobAttempt -JobName 'Job1'

        Removes all attempt records for Job1.
    .EXAMPLE
        PS C:\> Clear-JSMJobAttempt -JobName 'Job1' -Attempt 1,2

        Removes attempt records 1 and 2 for Job1, leaving any others intact.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'JobName', Justification = 'Used inside Where() scriptblock closure')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Attempt', Justification = 'Used inside Where() scriptblock closure')]
    [cmdletbinding(DefaultParameterSetName = 'All')]
    param(
        [parameter(ParameterSetName = 'SpecificJob',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [parameter(ParameterSetName = 'SpecificJobAttempt',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$JobName
        ,
        [parameter(ParameterSetName = 'SpecificJobAttempt',Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [int[]]$Attempt
    )
    Begin
    {
        Initialize-TrackingVariable
        switch ($PSCmdlet.ParameterSetName)
        {
            'All'
            {
                $script:JobAttempts.clear()
            }
        }
    }
    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'SpecificJob'
            {
                $toRemove = $script:JobAttempts.where({ $_.JobName -eq $JobName })
                foreach ($item in $toRemove)
                {
                    $script:JobAttempts.Remove($item)
                }
            }
            'SpecificJobAttempt'
            {
                $toRemove = $script:JobAttempts.where({ $_.JobName -eq $JobName -and $_.Attempt -in $Attempt })
                foreach ($item in $toRemove)
                {
                    $script:JobAttempts.Remove($item)
                }
            }
        }
    }
}
