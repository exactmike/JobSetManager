function Set-JSMJobAttempt
{
    <#
    .SYNOPSIS
        Records the completion or failure of a job attempt.
    .DESCRIPTION
        Finds the specified job attempt record by job name and attempt number, then sets the
        Stop timestamp, StopType, and marks the attempt as inactive.
    .PARAMETER JobName
        The name of the job whose attempt is being updated.
    .PARAMETER Attempt
        The attempt number to update.
    .PARAMETER StopType
        Whether the attempt completed successfully ('Complete') or failed ('Fail').
    .EXAMPLE
        PS C:\> Set-JSMJobAttempt -JobName 'Job1' -Attempt 1 -StopType Complete

        Marks attempt 1 of Job1 as successfully completed.
    #>
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
        $JobAttemptToSet.Stop = Get-Date
        $JobAttemptToSet.StopType = $StopType
        $JobAttemptToSet.Active = $false
    }
}