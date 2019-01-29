function Get-JSMJobSetYUMLURL
{
    [cmdletbinding(DefaultParameterSetName='Static')]
    param(
        [psobject[]]$JobSet
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [switch]$Progress
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $CompletedJobs
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $CurrentJobs
        ,
        [parameter(ParameterSetName = 'Progress',Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $FailedJobs
    )
    function Get-BGColor {
        param(
            $JobName
            ,
            $CurrentJobs
            ,
            $CompletedJobs
            ,
            $FailedJobs
        )
        if ($CompletedJobs.ContainsKey($JobName))
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
                {'palegreen'}
            }
        }
        elseif ($FailedJobs.ContainsKey($JobName))
        {
            'red'
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
                $JobColors=@{}
                foreach ($job in $JobSet)
                {
                    $JobName = $job | Select-Object -ExpandProperty Name
                    $JobColors.$($JobName) = "{bg:" + "$(Get-BGColor -JobName $JobName -CurrentJobs $CurrentJobs -CompletedJobs $CompletedJobs -FailedJobs $FailedJobs)" + "}"
                }
                $(
                    foreach ($job in $JobSet)
                    {
                        $JobName = $job | Select-Object -ExpandProperty Name
                        $jobReferences = $job | Select-Object -ExpandProperty DependsOnJobs

                        foreach ($jref in $jobReferences)
                        {
                            "[" + $JobName +' '+ $JobColors.$JobName "] -> [" + $jref + ' ' + $JobColors.$jref "]"
                        }
                    }
                ) -join ','
            }
        }
    )
    $string
    #"https://yuml.me/diagram/plain;dir:RL/class/" + $([uri]::EscapeDataString($string)) + ".jpg"
}