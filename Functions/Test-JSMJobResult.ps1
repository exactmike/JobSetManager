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
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 438
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
                        $message = "$JobName : Passed Validation AllowEmptyArray ($($ResultsValidation.AllowEmptyArray))"
                        Write-Verbose -Message $message
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 436
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
                            Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 420
                            $Result
                        }
                        $false
                        {
                            $message = "$JobName : FAILED Validation NotNull ($($ResultsValidation.NotNull)). Skipping other validations."
                            Write-Warning -Message $message
                            Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $false -EventID 421
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
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 422
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Failed Validation ValidateType ($($ResultsValidation.ValidateType.Name))"
                        Write-Warning -Message $message
                        $message = $message + " : Actual Type $($JobResults.gettype().name)"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $false -EventID 423
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
                        $message = $message + " : Actual Count $($JobResults.count)"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 424
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidateElementCountExpression ($($ResultsValidation.ValidateElementCountExpression)). Result Count: $($JobResults.count)"
                        Write-Warning -Message $message
                        $message = $message + " : Actual Count $($JobResults.count)"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $false -EventID 425
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
                        $message = $message + " : Contains Elements $($ResultsValidation.ValidateElementMember -join ';')"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 426
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidateElementMember ($($ResultsValidation.ValidateElementMember))"
                        Write-Warning -Message $message
                        $message = $message + " : Missing One or more Elements $($ResultsValidation.ValidateElementMember -join ';')"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $false -EventID 427
                    }
                    $Result
                }
                'ValidatePath'
                {
                    $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
                    Write-Verbose -Message $message
                    $Result = @(Test-Path -path $JobResults) -notcontains $false
                    if ($Result -eq $true)
                    {
                        $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
                        Write-Verbose -Message $message
                        $message = $message + " : ValidPath(s) $($JobResults -join ';')"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $true -EventID 428
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$JobName : Validation ValidatePath ($($ResultsValidation.ValidatePath))"
                        Write-Warning -Message $message
                        $message = $message + " :  InValidPath(s) in Paths $($JobResults -join ';')"
                        Add-JSMProcessingStatusEntry -Job $JobName -Message $message -Status $false -EventID 429
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
