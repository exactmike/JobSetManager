$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")


Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        Clear-JSMJobCompletion
    }
    AfterAll {
        Clear-JSMJobCompletion
    }

    Context "Returns the JobCompletions hashtable" {
        It "returns a hashtable" {
            Get-JSMJobCompletion | Should -BeOfType [hashtable]
        }
        It "reflects added completions" {
            Add-JSMJobCompletion -Name 'Job1'
            (Get-JSMJobCompletion).ContainsKey('Job1') | Should -Be $true
        }
        It "reflects cleared completions" {
            Clear-JSMJobCompletion
            (Get-JSMJobCompletion).Count | Should -Be 0
        }
    }
}
