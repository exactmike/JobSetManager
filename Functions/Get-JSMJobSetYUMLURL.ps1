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
    function Get-BGColor
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
        if ($JobCompletion.ContainsKey($JobName))
        {
            'limegreen'
        }
        elseif ($JobCurrent.ContainsKey($JobName))
        {
            switch ($JobFailure.ContainsKey($JobName))
            {
                $true
                {'palegoldenrod'}
                $false
                {'skyblue'}
            }
        }
        elseif ($JobFailure.ContainsKey($JobName))
        {
            'red'
        }
        else
        {
            'tan'
        }
    }
    #end function Get-BGColor
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
                    $Color = Get-BGColor -JobName $JobName -JobCurrent $JobCurrent -JobCompletion $JobCompletion -JobFailure $JobFailure
                    $JobYUML.$($JobName) = "[$JobName {bg:$Color}]"
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
    $string
    #"https://yuml.me/diagram/plain;dir:RL/class/" + $([uri]::EscapeDataString($string)) + ".jpg"
}