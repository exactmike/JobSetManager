$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Name', 'Value')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        New-JSMVariable -Name 'JSMTestSetVar' -Value 'original'
    }
    AfterAll {
        Remove-JSMVariable -Name 'JSMTestSetVar' -ErrorAction SilentlyContinue
    }

    Context "Updates an existing script-scope variable" {
        It "updates the variable value" {
            Set-JSMVariable -Name 'JSMTestSetVar' -Value 'updated'
            Get-JSMVariableValue -Name 'JSMTestSetVar' | Should -Be 'updated'
        }
        It "can update to a different type" {
            Set-JSMVariable -Name 'JSMTestSetVar' -Value 42
            Get-JSMVariableValue -Name 'JSMTestSetVar' | Should -Be 42
        }
        It "can update to null" {
            Set-JSMVariable -Name 'JSMTestSetVar' -Value $null
            Get-JSMVariableValue -Name 'JSMTestSetVar' | Should -BeNullOrEmpty
        }
    }
}
