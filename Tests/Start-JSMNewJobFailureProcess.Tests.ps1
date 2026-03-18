$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('CompletionFailures', 'StartJobFailures', 'StaleJobFailures', 'JobFailureRetryLimit')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }

    Context "No failures" {
        It "returns false when all failure sources are empty" {
            $result = Start-JSMNewJobFailureProcess -CompletionFailures @() -StartJobFailures @() -StaleJobFailures @() -JobFailureRetryLimit 3
            $result | Should -Be $false
        }
        It "returns false when all failure sources are null" {
            $result = Start-JSMNewJobFailureProcess -JobFailureRetryLimit 3
            $result | Should -Be $false
        }
    }

    Context "Aggregation" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
            $script:JobDef = [pscustomobject]@{
                Name                 = 'Job1'
                JobFailureRetryLimit = 10
                FailureType          = 'ResultValidation'
            }
        }
        AfterAll {
            Clear-JSMJobAttempt
            Clear-JSMJobFailure
        }
        It "returns false (retryable) when failure count is below retry limit" {
            $result = Start-JSMNewJobFailureProcess `
                -CompletionFailures @($script:JobDef) `
                -StartJobFailures @() `
                -StaleJobFailures @() `
                -JobFailureRetryLimit 3
            $result | Should -Be $false
        }
        It "aggregates failures from all three sources before routing" {
            $job2 = [pscustomobject]@{ Name = 'Job2'; JobFailureRetryLimit = 10; FailureType = 'PreJobCommands' }
            $job3 = [pscustomobject]@{ Name = 'Job3'; JobFailureRetryLimit = 10; FailureType = 'StaleJob' }
            $result = Start-JSMNewJobFailureProcess `
                -CompletionFailures @($script:JobDef) `
                -StartJobFailures @($job2) `
                -StaleJobFailures @($job3) `
                -JobFailureRetryLimit 3
            $result | Should -Be $false
        }
    }
}
