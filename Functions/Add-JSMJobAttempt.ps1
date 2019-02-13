function Add-JSMJobAttempt
{
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$JobName
        ,
        [parameter(Mandatory)]
        [int]$Attempt
        ,
        [parameter()]
        [ValidateSet('RSJob','PSJob')]
        [string]$JobType = 'RSJob'
    )
    Initialize-TrackingVariable
    $JobAttempt = [PSCustomObject]@{
        JobName = $JobName
        Attempt = $Attempt
        JobType = $JobType
        Active = $true
        Start = Get-Date
        Stop = $null
        StopType = 'None'
    }
    $script:JobAttempts.add($JobAttempt)
    $JobAttempt
}