function Get-JSMJobPending
{
    [cmdletbinding()]
    param(
        $JobRequired
    )
    $jobCompletions = Get-JSMJobCompletion
    $currentJobs = Get-JSMJobCurrent -JobRequired $JobRequired -JobCompletion $jobCompletions
    $failedJobs = Get-JSMJobFailure
    $Pending = $JobRequired | Where-object {
        $_.Name -notin $jobCompletions.Keys -and
        $_.Name -notin $currentJobs.Name -and
        $_.Name -notin $failedJobs.Keys
    }
    $pendingJobs = @{}
    foreach ($p in $Pending) {$pendingJobs.$($p.name) = $true}
    $pendingJobs
}