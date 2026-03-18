function Get-JSMJobPending
{
    <#
    .SYNOPSIS
        Returns a hashtable of required jobs that have not yet started or completed.
    .DESCRIPTION
        Determines which jobs are pending by excluding currently running and already-completed
        jobs from the required job list. Returns a hashtable keyed by job name.
    .PARAMETER JobRequired
        Hashtable of required job definition objects keyed by job name.
    .OUTPUTS
        [hashtable]
    .EXAMPLE
        PS C:\> Get-JSMJobPending -JobRequired $jobRequired

        Returns a hashtable of job names for all jobs that are pending.
    #>
    [cmdletbinding()]
    param(
        [hashtable]$JobRequired
    )
    $jobCompletions = Get-JSMJobCompletion
    $currentJobs = Get-JSMJobCurrent -JobRequired $JobRequired -JobCompletion $jobCompletions
    $Pending = $JobRequired.Values | Where-object {
        $_.Name -notin $jobCompletions.Keys -and
        $_.Name -notin $currentJobs.Keys
    }
    $pendingJobs = @{}
    foreach ($p in $Pending) {$pendingJobs.$($p.name) = $true}
    $pendingJobs
}