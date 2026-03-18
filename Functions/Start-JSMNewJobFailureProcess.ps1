function Start-JSMNewJobFailureProcess
{
    <#
    .SYNOPSIS
        Aggregates failure sources from the current loop iteration and routes them to Start-JSMJobFailureProcess.
    .DESCRIPTION
        Collects job failure objects from three sources — newly completed jobs that failed validation
        or result assignment (CompletionFailures), jobs that failed to start (StartJobFailures), and
        jobs whose active attempts were found to be stale (StaleJobFailures) — into a single list
        and passes them to Start-JSMJobFailureProcess. Returns $true if any failure is fatal,
        $false if all failures are retryable or there are no failures.
    .PARAMETER CompletionFailures
        Job failure objects returned by Start-JSMNewJobCompletionProcess.
    .PARAMETER StartJobFailures
        Job failure objects returned by Start-JSMJob for jobs that failed to start.
    .PARAMETER StaleJobFailures
        Job failure objects for jobs whose active attempts were not found in the job engine.
    .PARAMETER JobFailureRetryLimit
        Global retry limit passed through to Start-JSMJobFailureProcess.
    .OUTPUTS
        [bool] $true if a fatal failure occurred, $false otherwise.
    .EXAMPLE
        PS C:\> Start-JSMNewJobFailureProcess -CompletionFailures $cf -StartJobFailures $sf -StaleJobFailures $stale -JobFailureRetryLimit 3

        Aggregates all failure sources and routes them to failure processing.
    #>
    [cmdletbinding()]
    param(
        [parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [psobject[]]$CompletionFailures
        ,
        [parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [psobject[]]$StartJobFailures
        ,
        [parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [psobject[]]$StaleJobFailures
        ,
        [parameter()]
        [int]$JobFailureRetryLimit
    )
    $NewJobFailures = [System.Collections.Generic.List[psobject]]::new()
    if ($null -ne $CompletionFailures -and $CompletionFailures.Count -ge 1)
    {
        $CompletionFailures.foreach({$NewJobFailures.add($_)})
    }
    if ($null -ne $StartJobFailures -and $StartJobFailures.Count -ge 1)
    {
        $StartJobFailures.foreach({$NewJobFailures.add($_)})
    }
    if ($null -ne $StaleJobFailures -and $StaleJobFailures.Count -ge 1)
    {
        $StaleJobFailures.foreach({$NewJobFailures.add($_)})
    }
    if ($NewJobFailures.Count -ge 1)
    {
        $message = "Found $($NewJobFailures.Count) New Job Failure(s). Submitting to Start-JSMJobFailureProcess."
        Write-Verbose -Message $message
        Start-JSMJobFailureProcess -NewJobFailure $NewJobFailures -JobFailureRetryLimit $JobFailureRetryLimit
    }
    else
    {
        $false
    }
}
