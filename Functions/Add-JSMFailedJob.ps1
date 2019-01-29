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
}
