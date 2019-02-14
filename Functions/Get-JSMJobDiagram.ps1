function Get-JSMJobDiagram
{
    [CmdletBinding()]
    param
    (
        # One or more Job objects for which you would like a diagram of the inputs, outputs, and job dependencies
        [Parameter(Mandatory)]
        [psobject[]]$Job
    )

    begin
    {
    }

    process
    {
        foreach ($j in $Job)
        {
            graph job {
                node $j.name @{shape = $(if ($j.JobSplit -gt 1){'parallelogram'} else {'box'})}
                $j.DependsOnJobs.foreach({node $_ @{shape = 'invtriangle'}})
                $j.DependsOnJobs.foreach({edge $_ $j.name})
                node $j.ResultsVariableName @{shape='egg'}
                edge $j.name $j.ResultsVariableName
            } | Export-PSGraph
        }
    }

    end
    {
    }
}