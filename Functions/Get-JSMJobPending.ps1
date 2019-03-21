function Get-JSMJobPending
{
    [cmdletbinding()]
    param(
        $JobRequired
    )
    $completedJSMJobs = Get-JSMJobCompletion
    $currentJSMJobs = Get-JSMJobCurrent
    $pendingJobObjects = $JobRequired | Where-object {
        $_.Name -notin $CompletedJSMJobs.Keys -and
        $_.Name -notin $CurrentJSMJobs.JobName
    }
    $pendingJSMJobs = @{}
    foreach ($p in $pendingJobObjects) {$pendingJSMJobs.$($p.name) = $true}
    $pendingJSMJobs
}