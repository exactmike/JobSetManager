function Add-JSMJobFailure
{
    <#
    .SYNOPSIS
        Adds or updates a failure record for a JSM job in the JobFailures module variable.
    .DESCRIPTION
        Adds a new entry to the script-scoped JobFailures hashtable or updates an existing one.
        If the job already has a failure record, increments the failure count and appends
        the failure type. Also writes processing status entries for the failure event.
    .PARAMETER Name
        The name of the job that failed.
    .PARAMETER FailureType
        A string identifying the type of failure (e.g. 'StaleJob', 'ResultValidation').
    .PARAMETER Attempt
        The job attempt object associated with this failure.
    .EXAMPLE
        PS C:\> Add-JSMJobFailure -Name 'Job1' -FailureType 'ResultValidation' -Attempt $attempt

        Records a ResultValidation failure for Job1.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$Name
        ,
        [parameter(Mandatory)]
        [string]$FailureType
        ,
        [parameter(Mandatory)]
        [psobject]$Attempt
    )
    if ($true -ne $(Test-path -Path variable:script:JobFailures))
    {
        Initialize-TrackingVariable
    }
    switch ($Script:JobFailures.ContainsKey($Name))
    {
        $true
        {
            $Script:JobFailures.$($Name).FailureCount++
            $Script:JobFailures.$($Name).FailureType.add($FailureType)
            $Script:JobFailures.$($Name).FailedAttempt.add($Attempt)
        }
        $false
        {
            $Script:JobFailures.$($Name) = [PSCustomObject]@{
                FailureCount = 1
                FailureType = [System.Collections.Generic.List[string]]::new()
                FailedAttempt = [System.Collections.Generic.List[psobject]]::new()
            }
            $Script:JobFailures.$($Name).FailureType.add($FailureType)
            $Script:JobFailures.$($Name).FailedAttempt.add($Attempt)
        }
    }
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job Attempt Failed" -Status $false -EventID 427
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job $name added to Job Failures." -Status $false -EventID 502
}
