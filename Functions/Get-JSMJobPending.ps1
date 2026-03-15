function Get-JSMJobPending
{
    <#
    .SYNOPSIS
        Returns a hashtable of required jobs that have not yet started or completed.
    .DESCRIPTION
        Determines which jobs are pending by excluding currently running and already-completed
        jobs from the required job list. Returns a hashtable keyed by job name.
    .PARAMETER JobRequired
        The array of required job definition objects to evaluate.
    .OUTPUTS
        [hashtable]
    .EXAMPLE
        PS C:\> Get-JSMJobPending -JobRequired $jobRequired

        Returns a hashtable of job names for all jobs that are pending.
    #>
    [cmdletbinding()]
    param(
        $JobRequired
    )
    $jobCompletions = Get-JSMJobCompletion
    $currentJobs = Get-JSMJobCurrent -JobRequired $JobRequired -JobCompletion $jobCompletions
    $failedJobs = Get-JSMJobFailure
    $Pending = $JobRequired | Where-object {
        $_.Name -notin $jobCompletions.Keys -and
        $_.Name -notin $currentJobs.Name #-and
        #$_.Name -notin $failedJobs.Keys
    }
    $pendingJobs = @{}
    foreach ($p in $Pending) {$pendingJobs.$($p.name) = $true}
    $pendingJobs
}