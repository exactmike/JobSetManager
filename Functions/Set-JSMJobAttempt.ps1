function Set-JSMJobAttempt
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$JobName
        ,
        [parameter(Mandatory)]
        [int]$Attempt
        ,
        [parameter(Mandatory)]
        [ValidateSet('Fail','Complete')]
        [string]$StopType
    )

    $JobAttempt = @(Get-JSMJobAttempt -JobName $JobName -Attempt $Attempt)
    If ($null -ne $JobAttempt -and $JobAttempt.Count -eq 1)
    {
        $JobAttemptToSet = $JobAttempt[0]
        #$index = $script:JobAttempts.IndexOf($JobAttemptToSet)
        $JobAttemptToSet.Stop = Get-Date
        $JobAttemptToSet.StopType = $StopType
        $JobAttemptToSet.Active = $false
        #$script:JobAttempts.Set($index,$JobAttemptToSet)
    }
}