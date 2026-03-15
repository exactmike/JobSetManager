$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'UnitTests' {
    Context "TestFor = `$true (conditions must be present and true)" {
        BeforeAll {
            $ConditionValues = @{ CondA = $true; CondB = $true; CondC = $false }
        }

        It "Returns true when all conditions in list are true" {
            Test-JSMJobCondition -JobConditionList @('CondA','CondB') -ConditionValuesObject $ConditionValues -TestFor $true |
                Should -Be $true
        }

        It "Returns false when any condition in list is false" {
            Test-JSMJobCondition -JobConditionList @('CondA','CondC') -ConditionValuesObject $ConditionValues -TestFor $true |
                Should -Be $false
        }

        It "Returns false when a condition is missing from the values object" {
            Test-JSMJobCondition -JobConditionList @('CondA','Missing') -ConditionValuesObject $ConditionValues -TestFor $true |
                Should -Be $false
        }

        It "Returns true when condition list has a single true condition" {
            Test-JSMJobCondition -JobConditionList @('CondA') -ConditionValuesObject $ConditionValues -TestFor $true |
                Should -Be $true
        }
    }

    Context "TestFor = `$false (conditions must be absent or false)" {
        BeforeAll {
            $ConditionValues = @{ CondA = $true; CondB = $false }
        }

        It "Returns true when all conditions in list are false" {
            Test-JSMJobCondition -JobConditionList @('CondB') -ConditionValuesObject $ConditionValues -TestFor $false |
                Should -Be $true
        }

        It "Returns false when any condition in list is true" {
            Test-JSMJobCondition -JobConditionList @('CondA') -ConditionValuesObject $ConditionValues -TestFor $false |
                Should -Be $false
        }

        It "Returns false when a condition key is not present in the values object (treated as unknown/true)" {
            # Missing keys hit the 'default' branch which returns $true, failing the 'must be false' test
            Test-JSMJobCondition -JobConditionList @('Missing') -ConditionValuesObject $ConditionValues -TestFor $false |
                Should -Be $false
        }
    }
}
