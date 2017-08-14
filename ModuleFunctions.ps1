function Test-JobCondition
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]$JobConditionList
        ,
        [Parameter(Mandatory)]
        $ConditionValuesObject
        ,
        [Parameter(Mandatory)]
        [ValidateSet($true,$false)]
        [bool]$TestFor
    )
    switch ($TestFor)
    {
        $true
        {
            if (@(switch ($JobConditionList) {{$ConditionValuesObject.$_ -eq $true}{$true}{$ConditionValuesObject.$_ -eq $false}{$false} default {$false}}) -notcontains $false)
            {
                $true
            }
            else
            {
                $false    
            }
        }
        $false
        {
            if (@(switch ($JobConditionList) {{$ConditionValuesObject.$_ -eq $true}{$true}{$ConditionValuesObject.$_ -eq $false}{$false} default {$true}}) -notcontains $true)
            {
                $true
            }
            else
            {
                $false    
            }
        }
    }
}
function Test-JobResult
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
                    Write-Log -Message $message -EntryType Attempting
                    $Result = $JobResults -is $ResultsValidation.$_
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Log -Message $message -EntryType Succeeded
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Log -Message $message -EntryType Failed
                    }
                    Write-Output -InputObject $Result
                }
                'ValidateElementCountExpression'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Log -Message $message -EntryType Attempting
                    $Result = Invoke-Expression "$($JobResults.count) $($ResultsValidation.$_)"
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)). Result Count: $($JobResults.count)"
                        Write-Log -Message $message -EntryType Succeeded
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_)). Result Count: $($JobResults.count)"
                        Write-Log -Message $message -EntryType Failed
                    }
                    Write-Output -InputObject $Result
                }
                'ValidateElementMember'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Log -Message $message -EntryType Attempting                    
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
                        Write-Log -Message $message -EntryType Succeeded
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Log -Message $message -EntryType Failed
                    }
                    Write-Output -InputObject $Result
                }
                'ValidatePath'
                {
                    $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                    Write-Log -Message $message -EntryType Attempting                    
                    $Result = Test-Path -path $JobResults
                    if ($Result -eq $true)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Log -Message $message -EntryType Succeeded
                    }
                    if ($Result -eq $false)
                    {
                        $message = "$($DefinedJob.Name): Validation $_ ($($ResultsValidation.$_))"
                        Write-Log -Message $message -EntryType Failed
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
################################
#to develop
###############################
function Import-JobDefinitions
{
    $PossibleJobsFilePath = Join-Path (Get-ADExtractVariableValue PSScriptRoot) 'RSJobDefinitions.ps1'
    $PossibleJobs = &$PossibleJobsFilePath
}
function Update-ProcessStatus
{
    param($Job,$Message,$Status)
    if ((Test-Path 'variable:ProcessStatus') -eq $false)
    {$ProcessStatus = @()}
    $ProcessStatus += [pscustomobject]@{TimeStamp = Get-TimeStamp; Job = $Job; Message = $Message;Status = $Status}
}
