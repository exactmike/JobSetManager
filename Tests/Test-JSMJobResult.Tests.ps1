$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'UnitTests' {

    Context "NotNull validation" {
        It "Returns true when result is not null" {
            $result = [pscustomobject]@{Name='Test'}
            Test-JSMJobResult -ResultsValidation @{NotNull=$true} -JobResults $result -JobName 'TestJob' |
                Should -Be $true
        }
        It "Returns false when result is null" {
            Test-JSMJobResult -ResultsValidation @{NotNull=$true} -JobResults $null -JobName 'TestJob' |
                Should -Be $false
        }
    }

    Context "AllowNull validation" {
        It "Returns true when result is null and AllowNull is set" {
            Test-JSMJobResult -ResultsValidation @{AllowNull=$true} -JobResults $null -JobName 'TestJob' |
                Should -Be $true
        }
    }

    Context "AllowEmptyArray validation" {
        It "Returns true when result is empty array and AllowEmptyArray is set" {
            Test-JSMJobResult -ResultsValidation @{AllowEmptyArray=$true} -JobResults @() -JobName 'TestJob' |
                Should -Be $true
        }
    }

    Context "ValidateType validation" {
        It "Returns true when result is the expected type" {
            $result = @(1,2,3)
            Test-JSMJobResult -ResultsValidation @{ValidateType=[array]} -JobResults $result -JobName 'TestJob' |
                Should -Be $true
        }
        It "Returns false when result is not the expected type" {
            $result = 'a string'
            Test-JSMJobResult -ResultsValidation @{ValidateType=[array]} -JobResults $result -JobName 'TestJob' |
                Should -Be $false
        }
    }

    Context "ValidateElementCountExpression validation" {
        It "Returns true when count expression matches" {
            $result = @(1,2,3)
            Test-JSMJobResult -ResultsValidation @{ValidateElementCountExpression='-gt 2'} -JobResults $result -JobName 'TestJob' |
                Should -Be $true
        }
        It "Returns false when count expression does not match" {
            $result = @(1)
            Test-JSMJobResult -ResultsValidation @{ValidateElementCountExpression='-gt 2'} -JobResults $result -JobName 'TestJob' |
                Should -Be $false
        }
    }

    Context "ValidateElementMember validation" {
        It "Returns true when all required members are present" {
            $result = @([pscustomobject]@{Name='A';Age=1})
            Test-JSMJobResult -ResultsValidation @{ValidateElementMember=@('Name','Age')} -JobResults $result -JobName 'TestJob' |
                Should -Be $true
        }
        It "Returns false when a required member is missing" {
            $result = @([pscustomobject]@{Name='A'})
            Test-JSMJobResult -ResultsValidation @{ValidateElementMember=@('Name','Missing')} -JobResults $result -JobName 'TestJob' |
                Should -Be $false
        }
    }

    Context "ValidatePath validation" {
        It "Returns true for a valid path" {
            Test-JSMJobResult -ResultsValidation @{ValidatePath=$true} -JobResults $env:SystemRoot -JobName 'TestJob' |
                Should -Be $true
        }
        It "Returns false for an invalid path" {
            Test-JSMJobResult -ResultsValidation @{ValidatePath=$true} -JobResults 'C:\NotARealPath_XYZ123' -JobName 'TestJob' |
                Should -Be $false
        }
    }

    Context "No validation defined (implicit NotNull)" {
        It "Returns true when result is not null and no validation keys given" {
            # When no AllowNull key, NotNull is automatically added
            Test-JSMJobResult -ResultsValidation @{} -JobResults 'something' -JobName 'TestJob' |
                Should -Be $true
        }
    }
}
