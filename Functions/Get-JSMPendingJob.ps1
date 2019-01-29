function Get-JSMPendingJob
{
    [cmdletbinding()]
    param(
        $RequiredJob
    )
    $CompletedJobs = Get-JSMCompletedJob
    $CurrentJobs = Get-JSMCurrentJob -RequiredJob $RequiredJob -CompletedJob $CompletedJobs
    $FailedJobs = Get-JSMFailedJob
    $Pending = $RequiredJob | Where-object {
        $_.Name -notin $CompletedJobs.Keys -and
        $_.Name -notin $CurrentJobs.Name -and
        $_.Name -notin $FailedJobs.Keys
    }
    $PendingJobs = @{}
    foreach ($p in $Pending) {$PendingJobs.$($p.name) = $true}
    $PendingJobs
}