$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('NewJobFailure', 'JobFailureRetryLimit')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
    }

    Context "Fatal failure when retry limit is exceeded" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
            # Record 3 failed attempts
            $a1 = Add-JSMJobAttempt -JobName 'FatalJob' -Attempt 1 -JobType PSJob
            Set-JSMJobAttempt -JobName 'FatalJob' -Attempt 1 -StopType Fail
            $a2 = Add-JSMJobAttempt -JobName 'FatalJob' -Attempt 2 -JobType PSJob
            Set-JSMJobAttempt -JobName 'FatalJob' -Attempt 2 -StopType Fail
            $a3 = Add-JSMJobAttempt -JobName 'FatalJob' -Attempt 3 -JobType PSJob
            Set-JSMJobAttempt -JobName 'FatalJob' -Attempt 3 -StopType Fail
            Add-JSMJobFailure -Name 'FatalJob' -FailureType 'Timeout' -Attempt $a1
            Add-JSMJobFailure -Name 'FatalJob' -FailureType 'Timeout' -Attempt $a2
            Add-JSMJobFailure -Name 'FatalJob' -FailureType 'Timeout' -Attempt $a3
            $jobDef = [pscustomobject]@{ Name = 'FatalJob'; JobFailureRetryLimit = 3 }
            $script:FatalResult = Start-JSMJobFailureProcess -NewJobFailure @($jobDef) -JobFailureRetryLimit 3
        }
        AfterAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
        }
        It "returns true (fatal failure)" {
            $script:FatalResult | Should -Be $true
        }
        It "logs a processing status entry for EventID 599" {
            $entries = @(Get-JSMProcessingStatusEntry | Where-Object { $_.JobName -eq 'FatalJob' -and $_.EventID -eq 599 })
            $entries.Count | Should -BeGreaterThan 0
        }
    }

    Context "Retry when limit is not exceeded" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
            $a1 = Add-JSMJobAttempt -JobName 'RetryJob' -Attempt 1 -JobType PSJob
            Set-JSMJobAttempt -JobName 'RetryJob' -Attempt 1 -StopType Fail
            Add-JSMJobFailure -Name 'RetryJob' -FailureType 'Timeout' -Attempt $a1
            $jobDef = [pscustomobject]@{ Name = 'RetryJob'; JobFailureRetryLimit = 0 }
            $script:RetryResult = Start-JSMJobFailureProcess -NewJobFailure @($jobDef) -JobFailureRetryLimit 3
        }
        AfterAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
        }
        It "returns false (retryable, not fatal)" {
            $script:RetryResult | Should -Be $false
        }
        It "logs a retry status entry for EventID 510" {
            $entries = @(Get-JSMProcessingStatusEntry | Where-Object { $_.JobName -eq 'RetryJob' -and $_.EventID -eq 510 })
            $entries.Count | Should -BeGreaterThan 0
        }
    }

    Context "Per-job retry limit takes precedence when higher" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
            $a1 = Add-JSMJobAttempt -JobName 'PerJobLimitJob' -Attempt 1 -JobType PSJob
            Set-JSMJobAttempt -JobName 'PerJobLimitJob' -Attempt 1 -StopType Fail
            Add-JSMJobFailure -Name 'PerJobLimitJob' -FailureType 'Timeout' -Attempt $a1
            # Global limit=3, per-job limit=1 -> 1 failure >= max(1,3)=3? No: max(1,3)=3, count=1 < 3 -> retry
            # Test: per-job=5, global=3 -> max=5, count=1 < 5 -> retry (false)
            $jobDef = [pscustomobject]@{ Name = 'PerJobLimitJob'; JobFailureRetryLimit = 5 }
            $script:PerJobResult = Start-JSMJobFailureProcess -NewJobFailure @($jobDef) -JobFailureRetryLimit 3
        }
        AfterAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            Clear-JSMProcessingStatusEntry
        }
        It "uses the higher per-job limit (not fatal with 1 failure when limit is 5)" {
            $script:PerJobResult | Should -Be $false
        }
    }
}
