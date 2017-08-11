function Test-All
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]$ConditionList
        ,
        [Parameter(Mandatory)]
        $ConditionValuesObject
        ,
        [Parameter(Mandatory)]
        [bool]$TestForCondition
    )
}
Write-Verbose -Message "TestForCondition is $TestforCondition"
switch ($TestForCondition)
{
    {$_ -eq $true}
    {
        Write-Verbose -Message "We are Testing for condition True"
        if (
            @(
                foreach ($Condition in $ConditionList)
                {
                    {$ConditionValuesObject.$Condition -eq $true}
                    {$true}
                    {$ConditionValuesObject.$Condition -eq $false}
                    {$false}
                }
            ) -notcontains $false
        )
        {
            $true
        }
        else
        {
            $false    
        }
    }
    {$_ -eq $false}
    {
        if (@(switch ($ConditionList) {{$ConditionValuesObject.$_ -eq $true}{$true}{$ConditionValuesObject.$_ -eq $false}{$false}}) -notcontains $true)
        {
            $true
        }
        else
        {
            $false    
        }
    }
}