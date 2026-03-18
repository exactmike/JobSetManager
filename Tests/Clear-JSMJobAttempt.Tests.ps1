$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobName', 'Attempt')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Clear-JSMJobAttempt
        Add-JSMJobAttempt -JobName 'Job1' -Attempt 1 -JobType PSJob
        Add-JSMJobAttempt -JobName 'Job1' -Attempt 2 -JobType PSJob
        Add-JSMJobAttempt -JobName 'Job2' -Attempt 1 -JobType PSJob
    }
    AfterAll {
        Clear-JSMJobAttempt
    }

    Context "All parameter set" {
        It "clears all attempt records" {
            Clear-JSMJobAttempt
            @(& (Get-Module JobSetManager) { $script:JobAttempts }).Count | Should -Be 0
        }
    }

    Context "SpecificJob parameter set" {
        BeforeAll {
            Clear-JSMJobAttempt
            Add-JSMJobAttempt -JobName 'Job1' -Attempt 1 -JobType PSJob
            Add-JSMJobAttempt -JobName 'Job1' -Attempt 2 -JobType PSJob
            Add-JSMJobAttempt -JobName 'Job2' -Attempt 1 -JobType PSJob
            Clear-JSMJobAttempt -JobName 'Job1'
        }
        It "removes all attempts for the specified job" {
            @(Get-JSMJobAttempt -JobName 'Job1').Count | Should -Be 0
        }
        It "leaves attempts for other jobs intact" {
            @(Get-JSMJobAttempt -JobName 'Job2').Count | Should -Be 1
        }
        It "does not error when the job has no attempts" {
            { Clear-JSMJobAttempt -JobName 'NonExistentJob' } | Should -Not -Throw
        }
    }

    Context "SpecificJobAttempt parameter set" {
        BeforeAll {
            Clear-JSMJobAttempt
            Add-JSMJobAttempt -JobName 'Job1' -Attempt 1 -JobType PSJob
            Add-JSMJobAttempt -JobName 'Job1' -Attempt 2 -JobType PSJob
            Add-JSMJobAttempt -JobName 'Job1' -Attempt 3 -JobType PSJob
            Add-JSMJobAttempt -JobName 'Job2' -Attempt 1 -JobType PSJob
            Clear-JSMJobAttempt -JobName 'Job1' -Attempt 1,2
        }
        It "removes only the specified attempt numbers for the job" {
            $remaining = @(Get-JSMJobAttempt -JobName 'Job1')
            $remaining.Count | Should -Be 1
            $remaining[0].Attempt | Should -Be 3
        }
        It "leaves attempts for other jobs intact" {
            @(Get-JSMJobAttempt -JobName 'Job2').Count | Should -Be 1
        }
        It "does not error when the specified attempt does not exist" {
            { Clear-JSMJobAttempt -JobName 'Job1' -Attempt 99 } | Should -Not -Throw
        }
    }
}
