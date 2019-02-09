function Add-JSMJobFailure
{
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
            $Script:JobFailures.$($Name).FailureType += $FailureType
            $Script:JobFailures.$($Name).FailedAttempt += $null #will add the attempt object here later after adding attempt parameter and figuring out attempt tracking
        }
        $false
        {
            $Script:JobFailures.$($Name) = [PSCustomObject]@{
                FailureCount = 1
                FailureType = @($FailureType)
                FailedAttempt = @($null) #will add the attempt object here later after adding attempt parameter and figuring out attempt tracking
            }
        }
    }
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job Attempt Failed" -Status $false -EventID 427
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job $name added to Job Failures." -Status $false -EventID 502
}
