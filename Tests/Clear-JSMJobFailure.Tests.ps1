$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")


Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
    }
    AfterAll {
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
    }

    Context "Clears all failure entries" {
        BeforeAll {
            $attempt = Add-JSMJobAttempt -JobName 'FailJob1' -Attempt 1 -JobType PSJob
            Add-JSMJobFailure -Name 'FailJob1' -FailureType 'Timeout' -Attempt $attempt
        }
        It "removes all entries from JobFailures" {
            Clear-JSMJobFailure
            (Get-JSMJobFailure).Count | Should -Be 0
        }
    }

    Context "Safe to call when already empty" {
        It "does not throw when JobFailures is already empty" {
            Clear-JSMJobFailure
            { Clear-JSMJobFailure } | Should -Not -Throw
        }
    }
}
