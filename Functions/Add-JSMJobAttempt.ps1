function Add-JSMJobAttempt
{
    <#
    .SYNOPSIS
        Adds a new job attempt record to the JobAttempts module variable.
    .DESCRIPTION
        Creates a new job attempt object tracking the job name, attempt number, job type,
        start time, and active state. Appends the record to the script-scoped JobAttempts
        collection and outputs the new attempt object.
    .PARAMETER JobName
        The name of the job being attempted.
    .PARAMETER Attempt
        The attempt number (e.g. 1 for first attempt, 2 for first retry).
    .PARAMETER JobType
        The job engine used. PSJob (Start-Job) or ThreadJob (Start-ThreadJob). Defaults to PSJob.
    .OUTPUTS
        [pscustomobject]
    .EXAMPLE
        PS C:\> Add-JSMJobAttempt -JobName 'Job1' -Attempt 1 -JobType PSJob

        Creates and records attempt 1 of Job1 using PSJob, and outputs the attempt object.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$JobName
        ,
        [parameter(Mandatory)]
        [int]$Attempt
        ,
        [parameter()]
        [ValidateSet('PSJob','ThreadJob')]
        [string]$JobType = 'PSJob'
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