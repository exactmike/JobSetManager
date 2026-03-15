function Get-JSMJobDiagram
{
    <#
    .SYNOPSIS
        Generates a PSGraph diagram for one or more job definitions.
    .DESCRIPTION
        Uses PSGraph (graphviz) to produce a visual diagram for each job showing its
        dependencies and result variable. Split jobs are rendered as parallelograms;
        standard jobs as boxes. Requires the PSGraph module.
    .PARAMETER Job
        One or more job definition objects to diagram.
    .EXAMPLE
        PS C:\> Get-JSMJobDiagram -Job $jobDefinitions

        Renders and exports a diagram for each job definition provided.
    #>
    [CmdletBinding()]
    param
    (
        # One or more Job objects for which you would like a diagram of the inputs, outputs, and job dependencies
        [Parameter(Mandatory)]
        [psobject[]]$Job
    )

    begin
    {
        if (-not (Get-Command 'graph' -ErrorAction SilentlyContinue))
        {
            Write-Warning "Get-JSMJobDiagram requires the PSGraph module. Install with: Install-Module PSGraph"
            $script:PSGraphMissing = $true
            return
        }
        $script:PSGraphMissing = $false
    }

    process
    {
        if ($script:PSGraphMissing) { return }
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