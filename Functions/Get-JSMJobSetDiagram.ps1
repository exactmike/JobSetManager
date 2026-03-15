function Get-JSMJobSetDiagram
{
    <#
    .SYNOPSIS
        Generates a PSGraph flow diagram for an entire job set.
    .DESCRIPTION
        Produces a dependency flow diagram for all jobs in the set with virtual start/end nodes.
        In Progress mode, colors each job node based on its current state: pending (gainsboro),
        running (deepskyblue), failed-and-running (yellow1), failed (brown1), or
        completed (chartreuse). Requires the PSGraph module.
    .PARAMETER JobSet
        The array of job definition objects to diagram.
    .PARAMETER Progress
        When specified, enables Progress mode to color nodes by current job state.
    .PARAMETER JobCompletion
        Hashtable of completed job names. Required with -Progress.
    .PARAMETER JobCurrent
        Hashtable of currently running job names. Required with -Progress.
    .PARAMETER JobFailure
        Hashtable of failed job names. Required with -Progress.
    .EXAMPLE
        PS C:\> Get-JSMJobSetDiagram -JobSet $jobs

        Renders a static dependency flow diagram for the job set.
    .EXAMPLE
        PS C:\> Get-JSMJobSetDiagram -JobSet $jobs -Progress -JobCompletion $completions -JobCurrent $current -JobFailure $failures

        Renders a color-coded progress diagram showing real-time job states.
    #>
    [cmdletbinding(DefaultParameterSetName='Static')]
    param(
        [parameter(Mandatory)]
        [psobject[]]$JobSet
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [switch]$Progress
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowEmptyCollection()]
        $JobCompletion
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowEmptyCollection()]
        $JobCurrent
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowEmptyCollection()]
        $JobFailure
    )
    function Get-FillColor
    {
        param
        (
            $JobName
            ,
            $JobCurrent
            ,
            $JobCompletion
            ,
            $JobFailure
        )
        begin
        {
            if ($JobCompletion.ContainsKey($JobName))
            {
                'chartreuse'
            }
            elseif ($JobCurrent.ContainsKey($JobName))
            {
                switch ($JobFailure.ContainsKey($JobName))
                {
                    $true
                    {'yellow1'}
                    $false
                    {'deepskyblue'}
                }
            }
            elseif ($JobFailure.ContainsKey($JobName))
            {
                'brown1'
            }
            else
            {
                'gainsboro'
            }
        }
    }
    #end function Get-fillcolor
    if (-not (Get-Command 'graph' -ErrorAction SilentlyContinue))
    {
        Write-Warning "Get-JSMJobSetDiagram requires the PSGraph module. Install with: Install-Module PSGraph"
        return
    }
    $JobSetDependencies = $JobSet.DependsOnJobs | Select-Object -Unique
    $graphDefinition = $(Switch ($PSCmdlet.ParameterSetName)
    {
        'Static'
        {
            graph JobSet {
                node 'start'
                $JobSet.Where({$_.JobSplit -gt 1}).foreach({node $_.Name @{shape='parallelogram';style='filled';fillcolor='gainsboro'}})
                $JobSet.Where({$null -eq $_.JobSplit -or $_.JobSplit -le 1}).foreach({node $_.Name @{shape='box';style='filled';fillcolor='gainsboro'}})
                $JobSet.Where({$_.DependsOnJobs.count -eq 0}).ForEach({edge 'start' $_.Name})
                $JobSet.Where({$_.DependsOnJobs.count -gt 0}).ForEach({edge $_.DependsOnJobs $_.Name})
                node 'end'
                $JobSet.Where({$_.Name -notin $JobSetDependencies}).Foreach({edge $_.Name 'end'})
            }
        }
        'Progress'
        {
            $getFillColorSplat = @{
                JobFailure = $JobFailure
                JobCompletion = $JobCompletion
                JobCurrent = $JobCurrent
            }
            graph JobSet {
                node 'start'
                $JobSet.Where({$_.JobSplit -gt 1}).foreach({
                    node $_.Name @{shape='parallelogram';style='filled';fillcolor=$(Get-FillColor -jobName $_.Name @getFillColorSplat)}
                })
                $JobSet.Where({$null -eq $_.JobSplit -or $_.JobSplit -le 1}).foreach({
                    node $_.Name @{shape='box';style='filled';fillcolor=$(Get-FillColor -jobName $_.Name @getFillColorSplat)}
                })
                $JobSet.Where({$_.DependsOnJobs.count -eq 0}).ForEach({edge 'start' $_.Name})
                $JobSet.Where({$_.DependsOnJobs.count -gt 0}).ForEach({edge $_.DependsOnJobs $_.Name})
                node 'end'
                $JobSet.Where({$_.Name -notin $JobSetDependencies}).Foreach({edge $_.Name 'end'})
            }
        }
    })
    $graphDefinition | Export-PSGraph
}