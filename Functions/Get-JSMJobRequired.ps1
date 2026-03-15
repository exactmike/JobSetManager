function Get-JSMJobRequired
{
    <#
    .SYNOPSIS
        Filters a job definition set to those required given the specified conditions.
    .DESCRIPTION
        Returns only the job definitions whose OnCondition and OnNotCondition requirements
        are satisfied by the provided Condition hashtable. If no Condition is provided, all
        job definitions are returned. Returns $null (with a warning) if no jobs qualify.
    .PARAMETER Condition
        A hashtable of condition name/value pairs used to evaluate OnCondition and OnNotCondition
        properties on job definitions.
    .PARAMETER JobDefinition
        The full array of job definition objects to filter.
    .EXAMPLE
        PS C:\> Get-JSMJobRequired -JobDefinition $allJobs

        Returns all job definitions (no condition filtering).
    .EXAMPLE
        PS C:\> Get-JSMJobRequired -JobDefinition $allJobs -Condition @{IncludeOptionalStep=$true}

        Returns only job definitions whose conditions are satisfied by the provided hashtable.
    .OUTPUTS
        [pscustomobject[]] filtered job definitions, or $null if none qualify.
    #>
    [cmdletbinding()]
    param
    (
        $Condition
        ,
        [psobject[]]$JobDefinition
    )
    #Only the jobs that meet the settings conditions or not conditions are required
    if ($PSBoundParameters.ContainsKey('Condition'))
    {
        $RequiredJobFilter = [scriptblock] {
            (($_.OnCondition.count -eq 0) -or (Test-JSMJobCondition -JobConditionList $_.OnCondition -ConditionValuesObject $Condition -TestFor $True)) -and
            (($_.OnNOTCondition.count -eq 0) -or (Test-JSMJobCondition -JobConditionList $_.OnNotCondition -ConditionValuesObject $Condition -TestFor $False))
        }
    }
    else {
        $RequiredJobFilter = [scriptblock] {$true}
    }
    $RequiredJobs = @($JobDefinition | Where-Object -FilterScript $RequiredJobFilter)
    if ($RequiredJobs.Count -eq 0)
    {
        $message = "Get-RequiredJob: No Required Jobs Found"
        Write-Warning -Message $message
        Add-JSMProcessingStatusEntry -JobName 'RequiredJobs' -Message $message -Status $false -EventID 103
        $null
    }
    else
    {
        $message = "Get-RequiredJob: Found $($RequiredJobs.Count) RequiredJobs as follows: $($RequiredJobs.Name -join ', ')"
        Write-Verbose -Message $message
        Add-JSMProcessingStatusEntry -JobName 'RequiredJobs' -Message $message -Status $true -EventID 102
        $RequiredJobs
    }
}
