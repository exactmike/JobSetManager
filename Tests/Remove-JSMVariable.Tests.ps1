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
        New-JSMVariable -Name 'JSMTestRemoveVar' -Value 'toremove'
    }

    Context "Removes a script-scope variable" {
        It "removes the variable from the module script scope" {
            Remove-JSMVariable -Name 'JSMTestRemoveVar'
            $exists = & (Get-Module JobSetManager) { Test-Path variable:Script:JSMTestRemoveVar }
            $exists | Should -Be $false
        }
    }
}
