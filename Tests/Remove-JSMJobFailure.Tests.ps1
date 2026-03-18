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
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        Clear-JSMJobFailure
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
        $attempt1 = Add-JSMJobAttempt -JobName 'FailJob1' -Attempt 1 -JobType PSJob
        $attempt2 = Add-JSMJobAttempt -JobName 'FailJob2' -Attempt 1 -JobType PSJob
        Add-JSMJobFailure -Name 'FailJob1' -FailureType 'Timeout' -Attempt $attempt1
        Add-JSMJobFailure -Name 'FailJob2' -FailureType 'Timeout' -Attempt $attempt2
    }
    AfterAll {
        Clear-JSMJobFailure
        Clear-JSMJobAttempt
        Clear-JSMProcessingStatusEntry
    }

    Context "Removes the specified entry" {
        BeforeAll {
            Remove-JSMJobFailure -Name 'FailJob1'
        }
        It "removes the named job from JobFailures" {
            (Get-JSMJobFailure).ContainsKey('FailJob1') | Should -Be $false
        }
        It "leaves other failure entries intact" {
            (Get-JSMJobFailure).ContainsKey('FailJob2') | Should -Be $true
        }
    }

    Context "Safe to remove a non-existent entry" {
        It "does not throw when the entry does not exist" {
            { Remove-JSMJobFailure -Name 'NonExistentJob' } | Should -Not -Throw
        }
    }
}
