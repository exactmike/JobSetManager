function Get-JFMJobSetDependencyYUMLDefinition
{
    [cmdletbinding()]
    param(
        [psobject[]]$JobSet
    )
    $(
        foreach ($job in $JobSet)
        {
            $JobName = $job | Select-Object -ExpandProperty Name
            $jobReferences = $job | Select-Object -ExpandProperty DependsOnJobs
            foreach ($jref in $jobReferences)
            {
                "[" + $JobName + "] -> [" + $jref + "]"
            }
        }
    ) -join ','
}
