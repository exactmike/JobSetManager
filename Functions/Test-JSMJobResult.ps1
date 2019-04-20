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
                    $message = "$JobName : Processing Validation AllowNull ($($ResultsValidation.AllowNull))"
                    Write-Verbose -Message $message
                    $Result = $null -eq $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Passed Validation AllowNull ($($ResultsValidation.AllowNull))"
                        Write-Verbose -Message $message
                        $message = "$JobName : Validation AllowNull ($($ResultsValidation.AllowNull)) Passed. Skipping other validations."
                        Write-Verbose -Message $message
                        $Result
                        break
                    }
                }
                'AllowEmptyArray'
                {
                    $message = "$JobName : Processing Validation AllowEmptyArray ($($ResultsValidation.AllowEmptyArray))"
                    Write-Verbose -Message $message
                    $Result = $JobResults.count -eq 0
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Passed Validation $AllowEmptyArray ($($ResultsValidation.AllowEmptyArray))"
                        Write-Verbose -Message $message
                        $message = "$JobName : Validation AllowEmptyArray ($($ResultsValidation.AllowEmptyArray)) Passed. Skipping other validations."
                        Write-Verbose -Message $message
                        $Result
                        break
                    }
                }
                'NotNull'
                {
                    $message = "$JobName : Processing Validation NotNull ($($ResultsValidation.NotNull))"
                    Write-Verbose -Message $message
                    $Result = $null -ne $JobResults
                    switch ($Result)
                    {
                        $true
                        {
                            $message = "$JobName : Passed Validation NotNull ($($ResultsValidation.NotNull))"
                            Write-Verbose -Message $message
                            $Result
                        }
                        $false
                        {
                            $message = "$JobName : FAILED Validation NotNull ($($ResultsValidation.NotNull)). Skipping other validations."
                            Write-Warning -Message $message
                            $Result
                            break
                        }
                    }
                }
                'ValidateType'
                {
                    $message = "$JobName : Processing Validation ValidateType ($($ResultsValidation.ValidateType.Name))"
                    Write-Verbose -Message $message
                    $Result = $JobResults -is $($ResultsValidation.ValidateType)
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Passed Validation ValidateType ($($ResultsValidation.ValidateType.Name))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Failed Validation ValidateType ($($ResultsValidation.ValidateType.Name))"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidateElementCountExpression'
                {
                    $message = "$JobName : Validation ValidateElementCountExpression ($($ResultsValidation.ValidateElementCountExpression))"
                    Write-Verbose -Message $message
                    $Result = Invoke-Expression "$($JobResults.count) $($ResultsValidation.ValidateElementCountExpression)"
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Validation ValidateElementCountExpression ($($ResultsValidation.ValidateElementCountExpression)). Result Count: $($JobResults.count)"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidateElementCountExpression ($($ResultsValidation.ValidateElementCountExpression)). Result Count: $($JobResults.count)"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidateElementMember'
                {
                    $message = "$JobName : Validation ValidateElementMember ($($ResultsValidation.ValidateElementMember))"
                    Write-Verbose -Message $message
                    $Result = $(
                        $MemberNames = @($JobResults[0] | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)
                        if
                        (
                            @(
                                switch ($ResultsValidation.ValidateElementMember)
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
                        $message = "$JobName : Validation ValidateElementMember ($($ResultsValidation.ValidateElementMember))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidateElementMember ($($ResultsValidation.ValidateElementMember))"
                        Write-Warning -Message $message
                    }
                    $Result
                }
                'ValidatePath'
                {
                    $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
                    Write-Verbose -Message $message
                    $Result = Test-Path -path $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
                        Write-Verbose -Message $message
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
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
