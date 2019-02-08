function Get-JSMJobSetYUMLURL
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
        [AllowNull()]
        [AllowEmptyCollection()]
        $JobCompletion
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $JobCurrent
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $JobFailure
    )
    function Get-BGColor {
        param(
            $JobName
            ,
            $CurrentJobs
            ,
            $JobCompletions
            ,
            $FailedJobs
        )
        if ($JobCompletions.ContainsKey($JobName))
        {
            'limegreen'
        }
        elseif ($CurrentJobs.ContainsKey($JobName))
        {
            switch ($FailedJobs.ContainsKey($JobName))
            {
                $true
                {'palegoldenrod'}
                $false
                {'skyblue'}
            }
        }
        elseif ($FailedJobs.ContainsKey($JobName))
        {
            'red'
        }
        else
        {
            'tan'
        }
    }
    $string = $(
        Switch ($PSCmdlet.ParameterSetName)
        {
            'Static'
            {
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
            'Progress'
            {
                $JobYUML=@{}
                foreach ($job in $JobSet)
                {
                    $JobName = $job | Select-Object -ExpandProperty Name
                    $Color = Get-BGColor -JobName $JobName -CurrentJobs $CurrentJobs -JobCompletions $JobCompletions -FailedJobs $FailedJobs
                    $JobYUML.$($JobName) = "[ $JobName {bg:$Color}]"
                }
                $(
                    foreach ($job in $JobSet)
                    {
                        $JobName = $job | Select-Object -ExpandProperty Name
                        $JobReferences = $job | Select-Object -ExpandProperty DependsOnJobs

                        foreach ($jref in $JobReferences)
                        {
                            "$($JobYUML.$JobName) <- $($JobYUML.$jref)"
                        }
                    }
                ) -join ','
            }
        }
    )
    #$string
    "https://yuml.me/diagram/plain;dir:RL/class/" + $([uri]::EscapeDataString($string)) + ".jpg"
}