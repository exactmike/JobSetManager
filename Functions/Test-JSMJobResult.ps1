function Test-JSMJobResult
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$ResultsValidation
        ,
        [parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        $JobResults
        ,
        [parameter()]
        [string]$JobName
    )
    if (-not $ResultsValidation.ContainsKey('AllowNull'))
    {
        $ResultsValidation.'NotNull' = $true
    }
    if
    (
        @(
            switch ($ResultsValidation.Keys)
            {
                'AllowNull'
                {
                    $message = "$($DefinedJob.Name): Processing Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $null -eq $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Passed Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)) Passed. Skipping other validations."
                        Write-Verbose -Message $message
                        $Result
                        break
                    }
                }
                'AllowEmptyArray'
                {
                    $message = "$($DefinedJob.Name): Processing Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $JobResults.count -eq 0
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Passed Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)) Passed. Skipping other validations."
                        Write-Verbose -Message $message
                        $Result
                        break
                    }
                }
                'NotNull'
                {
                    $message = "$($DefinedJob.Name): Processing Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $null -ne $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Passed Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                        $Result
                    }
                    else
                    {
                        $message = "$($DefinedJob.Name): FAILED Validation $_ ($($ResultsValidation.$_)). Skipping other validations."
                        Write-Warning -Message $message
                        $Result
                        break
                    }

                }
                'ValidateType'
                {
                    $message = "$($DefinedJob.Name): Processing Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $JobResults -is $ResultsValidation.$_
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Passed Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Failed Validation $_ ($($ResultsValidation.$_))"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidateElementCountExpression'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = Invoke-Expression "$($JobResults.count) $($ResultsValidation.$_)"
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)). Result Count: $($JobResults.count)"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)). Result Count: $($JobResults.count)"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidateElementMember'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $(
                        $MemberNames = @($JobResults[0] | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)
                        if
                        (
                            @(
                                switch ($ResultsValidation.$_)
                                {
                                    {$_ -in $MemberNames}
                                    {$true}
                                    {$_ -notin $MemberNames}
                                    {$false}
                                }
                            ) -contains $false
                        )
                        {$false}
                        else
                        {$true}
                    )
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidatePath'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = Test-Path -path $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Warning -Message $message
                    }
                    $Result
                }
            }
        ) -contains $false
    )
    {
        $false
    }
    else
    {
        $true
    }
}
