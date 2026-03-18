$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")


Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
    }

    Context "Clears all completion entries" {
        BeforeAll {
            Add-JSMJobCompletion -Name 'Job1'
            Add-JSMJobCompletion -Name 'Job2'
        }
        It "removes all entries from JobCompletions" {
            Clear-JSMJobCompletion
            (Get-JSMJobCompletion).Count | Should -Be 0
        }
    }

    Context "Safe to call when already empty" {
        It "does not throw when JobCompletions is already empty" {
            Clear-JSMJobCompletion
            { Clear-JSMJobCompletion } | Should -Not -Throw
        }
    }
}
