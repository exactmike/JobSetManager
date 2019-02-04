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
        $JobAttempt[0].Stop = Get-Date
        $JobAttempt[0].StopType = $StopType
        $JobAttempt[0].Active = $false
    }
}