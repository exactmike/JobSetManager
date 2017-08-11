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
        [hashtable]$JobResultsValidation
        ,
        [parameter(Mandatory)]
        $JobResults
    )
    if
    (
        @(
            switch ($JobResultsValidation.Keys)
            {
                'ValidateType'
                {
                    $JobResults -is $JobResultsValidation.$_
                }
                'ValidateElementCountExpression'
                {
                    Invoke-Expression "$($JobResults.count) $($JobResultsValidation.$_)"
                }
                'ValidateElementMember'
                {
                    $MemberNames = @($JobResults[0] | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)
                    if
                    (
                        @(
                            switch ($JobResultsValidation.$_)
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
                }
                'ValidatePath'
                {
                    Test-Path -path $JobResults
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
