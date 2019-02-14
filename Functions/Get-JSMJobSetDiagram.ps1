function Get-JSMJobSetDiagram
{
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