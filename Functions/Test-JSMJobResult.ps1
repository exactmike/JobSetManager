function Test-JSMJobResult
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [hashtable]$ResultsValidation
        ,
        [parameter(Mandatory)]
        $JobResults
        ,
        [parameter()]
        [string]$JobName
    )
    if
    (
        @(
            switch ($ResultsValidation.Keys)
            {
                'ValidateType'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Verbose -Message $message
                    $Result = $JobResults -is $ResultsValidation.$_
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
                    Write-Output -InputObject $Result
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
                    Write-Output -InputObject $Result
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
                                    {Write-Output -InputObject $true}
                                    {$_ -notin $MemberNames}
                                    {Write-Output -InputObject $false}
                                }
                            ) -contains $false
                        )
                        {Write-Output -InputObject $false}
                        else
                        {Write-Output -InputObject $true}
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
                    Write-Output -InputObject $Result
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
                    Write-Output -InputObject $Result
                }
            }
        ) -contains $false
    )
    {
        Write-Output -InputObject $false
    }
    else
    {
        Write-output -inputObject $true
    }
}
