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
    AfterEach {
        & (Get-Module JobSetManager) {
            Remove-Variable -Name 'JSMTestNewVar' -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name 'JSMTestNewVarHT' -Scope Script -ErrorAction SilentlyContinue
        }
    }

    Context "Creates a script-scope variable" {
        It "creates the variable in the module script scope" {
            New-JSMVariable -Name 'JSMTestNewVar' -Value 'created'
            $result = & (Get-Module JobSetManager) { $script:JSMTestNewVar }
            $result | Should -Be 'created'
        }
        It "does not create the variable in the local scope" {
            New-JSMVariable -Name 'JSMTestNewVar' -Value 'localcheck'
            $localExists = Test-Path variable:JSMTestNewVar
            $localExists | Should -Be $false
        }
    }

    Context "Accepts various value types" {
        It "creates a variable with a hashtable value" {
            New-JSMVariable -Name 'JSMTestNewVarHT' -Value @{A = 1}
            $result = Get-JSMVariableValue -Name 'JSMTestNewVarHT'
            $result | Should -BeOfType [hashtable]
        }
    }
}
