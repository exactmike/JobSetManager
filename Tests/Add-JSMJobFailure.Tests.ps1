$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Name', 'FailureType', 'Attempt')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }

    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Clear-JSMJobAttempt
        Clear-JSMJobFailure
        Clear-JSMProcessingStatusEntry
        $script:Attempt1 = Add-JSMJobAttempt -JobName 'Job1' -Attempt 1 -JobType PSJob
    }
    AfterAll {
        Clear-JSMJobAttempt
        Clear-JSMJobFailure
        Clear-JSMProcessingStatusEntry
    }

    Context "New failure entry" {
        BeforeAll {
            Add-JSMJobFailure -Name 'Job1' -FailureType 'ResultValidation' -Attempt $script:Attempt1
            $script:Failure = (Get-JSMJobFailure).Job1
        }
        It "sets FailureCount to 1" {
            $script:Failure.FailureCount | Should -Be 1
        }
        It "sets FailureType to the provided value" {
            $script:Failure.FailureType | Should -Contain 'ResultValidation'
        }
        It "stores the attempt object in FailedAttempt" {
            $script:Failure.FailedAttempt[0] | Should -Not -BeNullOrEmpty
            $script:Failure.FailedAttempt[0].JobName | Should -Be 'Job1'
            $script:Failure.FailedAttempt[0].Attempt | Should -Be 1
        }
        It "does not store null in FailedAttempt" {
            $null | Should -Not -BeIn $script:Failure.FailedAttempt
        }
        It "writes a processing status entry for EventID 427" {
            $entries = @(Get-JSMProcessingStatusEntry | Where-Object { $_.JobName -eq 'Job1' -and $_.EventID -eq 427 })
            $entries.Count | Should -BeGreaterThan 0
        }
        It "writes a processing status entry for EventID 502" {
            $entries = @(Get-JSMProcessingStatusEntry | Where-Object { $_.JobName -eq 'Job1' -and $_.EventID -eq 502 })
            $entries.Count | Should -BeGreaterThan 0
        }
    }

    Context "Update existing failure entry" {
        BeforeAll {
            $script:Attempt2 = Add-JSMJobAttempt -JobName 'Job1' -Attempt 2 -JobType PSJob
            Add-JSMJobFailure -Name 'Job1' -FailureType 'StaleJob' -Attempt $script:Attempt2
            $script:Failure2 = (Get-JSMJobFailure).Job1
        }
        It "increments FailureCount to 2" {
            $script:Failure2.FailureCount | Should -Be 2
        }
        It "appends the new FailureType" {
            $script:Failure2.FailureType | Should -Contain 'ResultValidation'
            $script:Failure2.FailureType | Should -Contain 'StaleJob'
        }
        It "has two FailedAttempt entries" {
            $script:Failure2.FailedAttempt.Count | Should -Be 2
        }
        It "second FailedAttempt entry matches the second attempt object" {
            $script:Failure2.FailedAttempt[1].JobName | Should -Be 'Job1'
            $script:Failure2.FailedAttempt[1].Attempt | Should -Be 2
        }
        It "does not store null in FailedAttempt after update" {
            $null | Should -Not -BeIn $script:Failure2.FailedAttempt
        }
    }
}
