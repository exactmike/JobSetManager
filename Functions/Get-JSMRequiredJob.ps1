function Get-JSMRequiredJob
{
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
    $RequiredJobs = @($JobDefinitions | Where-Object -FilterScript $RequiredJobFilter)
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
