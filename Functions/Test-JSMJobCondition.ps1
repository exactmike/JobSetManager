function Test-JSMJobCondition
{
    <#
    .SYNOPSIS
        Tests a list of condition names against a condition values object.
    .DESCRIPTION
        Checks whether all conditions in JobConditionList evaluate to the expected boolean
        value (TestFor) in the ConditionValuesObject. Used internally to evaluate OnCondition
        and OnNotCondition on job definitions.
    .PARAMETER JobConditionList
        One or more condition names to test.
    .PARAMETER ConditionValuesObject
        A hashtable or object whose properties represent condition names and boolean values.
    .PARAMETER TestFor
        The expected boolean value for each condition. $true means all must be true; $false
        means all must be false or absent.
    .EXAMPLE
        PS C:\> Test-JSMJobCondition -JobConditionList @('FeatureA') -ConditionValuesObject @{FeatureA=$true} -TestFor $true

        Returns $true because FeatureA is $true in the values object.
    .OUTPUTS
        [bool]
    #>
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
