$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobName', 'Attempt', 'StopType')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Clear-JSMJobAttempt
    }
    AfterAll {
        Clear-JSMJobAttempt
    }

    Context "Complete stop type" {
        BeforeAll {
            Add-JSMJobAttempt -JobName 'SetTestJob' -Attempt 1 -JobType PSJob
            Set-JSMJobAttempt -JobName 'SetTestJob' -Attempt 1 -StopType Complete
            $script:Attempt = @(Get-JSMJobAttempt -JobName 'SetTestJob')[0]
        }
        It "sets StopType to Complete" {
            $script:Attempt.StopType | Should -Be 'Complete'
        }
        It "sets Active to false" {
            $script:Attempt.Active | Should -Be $false
        }
        It "sets Stop to a DateTime" {
            $script:Attempt.Stop | Should -BeOfType [datetime]
        }
    }

    Context "Fail stop type" {
        BeforeAll {
            Clear-JSMJobAttempt
            Add-JSMJobAttempt -JobName 'SetTestJob' -Attempt 1 -JobType PSJob
            Set-JSMJobAttempt -JobName 'SetTestJob' -Attempt 1 -StopType Fail
            $script:Attempt2 = @(Get-JSMJobAttempt -JobName 'SetTestJob')[0]
        }
        It "sets StopType to Fail" {
            $script:Attempt2.StopType | Should -Be 'Fail'
        }
        It "sets Active to false" {
            $script:Attempt2.Active | Should -Be $false
        }
    }

    Context "Targets the correct attempt number" {
        BeforeAll {
            Clear-JSMJobAttempt
            Add-JSMJobAttempt -JobName 'MultiAttemptJob' -Attempt 1 -JobType PSJob
            Add-JSMJobAttempt -JobName 'MultiAttemptJob' -Attempt 2 -JobType PSJob
            Set-JSMJobAttempt -JobName 'MultiAttemptJob' -Attempt 1 -StopType Fail
        }
        It "only modifies the specified attempt" {
            $a2 = @(Get-JSMJobAttempt -JobName 'MultiAttemptJob' -Attempt 2)[0]
            $a2.Active | Should -Be $true
            $a2.StopType | Should -Be 'None'
        }
    }
}
