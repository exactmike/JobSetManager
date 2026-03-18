$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Name')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        New-JSMVariable -Name 'JSMTestGetVarValue' -Value 'ExpectedValue'
    }
    AfterAll {
        Remove-JSMVariable -Name 'JSMTestGetVarValue' -ErrorAction SilentlyContinue
    }

    Context "Returns the value of the script-scope variable" {
        It "returns the correct value" {
            $result = Get-JSMVariableValue -Name 'JSMTestGetVarValue'
            $result | Should -Be 'ExpectedValue'
        }
        It "returns just the value, not a PSVariable object" {
            $result = Get-JSMVariableValue -Name 'JSMTestGetVarValue'
            $result | Should -BeOfType [string]
        }
    }

    Context "Works with hashtable values" {
        BeforeAll {
            New-JSMVariable -Name 'JSMTestGetVarHashtable' -Value @{Key = 'Val'}
        }
        AfterAll {
            Remove-JSMVariable -Name 'JSMTestGetVarHashtable' -ErrorAction SilentlyContinue
        }
        It "returns a hashtable value" {
            $result = Get-JSMVariableValue -Name 'JSMTestGetVarHashtable'
            $result | Should -BeOfType [hashtable]
            $result['Key'] | Should -Be 'Val'
        }
    }
}
