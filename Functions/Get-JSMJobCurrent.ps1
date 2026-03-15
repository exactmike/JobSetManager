function Get-JSMJobCurrent
{
    <#
    .SYNOPSIS
        Returns a hashtable of currently running jobs from the required job set.
    .DESCRIPTION
        Queries Get-Job for native PS jobs matching the required job names. For split jobs,
        checks $script:SplitJobGroups for sub-job names. Returns a hashtable keyed by job
        name for jobs that are running but not yet completed.
    .PARAMETER JobRequired
        The full list of job definition objects for this job set.
    .PARAMETER JobCompletion
        A hashtable of already-completed job names (keys). Jobs in this set are excluded.
    .EXAMPLE
        PS C:\> Get-JSMJobCurrent -JobRequired $jobs -JobCompletion $completions

        Returns a hashtable of job names that are currently running.
    .OUTPUTS
        [hashtable] keyed by job name; values are $true.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [psobject[]]$JobRequired
        ,
        [parameter(Mandatory)]
        [hashtable]$JobCompletion
    )
    $NativeJobs = @(Get-Job)
    $CurrentJobs = @{}
    foreach ($jr in $JobRequired)
    {
        if ($jr.Name -in $JobCompletion.Keys) { continue }
        # Check direct name match (regular jobs)
        if ($NativeJobs | Where-Object { $_.Name -eq $jr.Name })
        {
            $CurrentJobs[$jr.Name] = $true
            continue
        }
        # Check split sub-jobs via SplitJobGroups
        if ($null -ne $script:SplitJobGroups -and $script:SplitJobGroups.ContainsKey($jr.Name))
        {
            $subJobNames = $script:SplitJobGroups[$jr.Name]
            if ($NativeJobs | Where-Object { $_.Name -in $subJobNames })
            {
                $CurrentJobs[$jr.Name] = $true
            }
        }
    }
    $CurrentJobs
}
