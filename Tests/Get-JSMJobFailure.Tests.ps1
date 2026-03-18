$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")


Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        Clear-JSMJobFailure
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
    }
    AfterAll {
        Clear-JSMJobFailure
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
    }

    Context "Returns the JobFailures hashtable" {
        It "returns a hashtable" {
            Get-JSMJobFailure | Should -BeOfType [hashtable]
        }
        It "reflects added failures" {
            $attempt = Add-JSMJobAttempt -JobName 'FailJob' -Attempt 1 -JobType PSJob
            Add-JSMJobFailure -Name 'FailJob' -FailureType 'Timeout' -Attempt $attempt
            (Get-JSMJobFailure).ContainsKey('FailJob') | Should -Be $true
        }
        It "reflects cleared failures" {
            Clear-JSMJobFailure
            (Get-JSMJobFailure).Count | Should -Be 0
        }
    }
}
