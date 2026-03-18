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
        New-JSMVariable -Name 'JSMTestGetVar' -Value 'TestValue'
    }
    AfterAll {
        Remove-JSMVariable -Name 'JSMTestGetVar' -ErrorAction SilentlyContinue
    }

    Context "Returns the script-scope variable object" {
        It "returns a PSVariable object" {
            $result = Get-JSMVariable -Name 'JSMTestGetVar'
            $result | Should -BeOfType [System.Management.Automation.PSVariable]
        }
        It "returns the variable with the correct name" {
            $result = Get-JSMVariable -Name 'JSMTestGetVar'
            $result.Name | Should -Be 'JSMTestGetVar'
        }
        It "returns the variable with the correct value" {
            $result = Get-JSMVariable -Name 'JSMTestGetVar'
            $result.Value | Should -Be 'TestValue'
        }
    }

    Context "Returns the variable for a known module tracking variable" {
        It "can retrieve the JobAttempts tracking variable" {
            $result = Get-JSMVariable -Name 'JobAttempts'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'JobAttempts'
        }
    }
}
