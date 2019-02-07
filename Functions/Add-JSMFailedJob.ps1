function Add-JSMFailedJob
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$Name
        ,
        [parameter(Mandatory)]
        [string]$FailureType
    )
    $Script:FailedJobs = Get-JSMFailedJob
    switch ($Script:FailedJobs.ContainsKey($Name))
    {
        $true
        {
            $Script:FailedJobs.$($Name).FailureCount++
            $Script:FailedJobs.$($Name).FailureType += $FailureType
        }
        $false
        {
            $Script:FailedJobs.$($Name) = [PSCustomObject]@{
                FailureCount = 1
                FailureType = @($FailureType)
            }
        }
    }
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job Attempt Failed" -Status $false -EventID 427
    Add-JSMProcessingStatusEntry -JobName $Name -Message "Job $name added to Job Failures." -Status $false -EventID 502
}
