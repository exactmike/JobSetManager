$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobName', 'Attempt', 'JobType')
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

    Context "Creates attempt record with correct properties" {
        BeforeAll {
            $script:Result = Add-JSMJobAttempt -JobName 'TestJob' -Attempt 1 -JobType PSJob
        }
        It "outputs the new attempt object" {
            $script:Result | Should -Not -BeNullOrEmpty
        }
        It "sets JobName correctly" {
            $script:Result.JobName | Should -Be 'TestJob'
        }
        It "sets Attempt correctly" {
            $script:Result.Attempt | Should -Be 1
        }
        It "sets JobType correctly" {
            $script:Result.JobType | Should -Be 'PSJob'
        }
        It "sets Active to true" {
            $script:Result.Active | Should -Be $true
        }
        It "sets StopType to None" {
            $script:Result.StopType | Should -Be 'None'
        }
        It "sets Start to a DateTime" {
            $script:Result.Start | Should -BeOfType [datetime]
        }
        It "sets Stop to null" {
            $script:Result.Stop | Should -BeNullOrEmpty
        }
        It "records the attempt in the module variable" {
            @(Get-JSMJobAttempt -JobName 'TestJob').Count | Should -Be 1
        }
    }

    Context "Defaults JobType to PSJob" {
        BeforeAll {
            Clear-JSMJobAttempt
            $script:Result2 = Add-JSMJobAttempt -JobName 'TestJob2' -Attempt 1
        }
        It "defaults JobType to PSJob" {
            $script:Result2.JobType | Should -Be 'PSJob'
        }
    }

    Context "Accepts ThreadJob type" {
        BeforeAll {
            Clear-JSMJobAttempt
            $script:Result3 = Add-JSMJobAttempt -JobName 'TestJob3' -Attempt 1 -JobType ThreadJob
        }
        It "stores ThreadJob type" {
            $script:Result3.JobType | Should -Be 'ThreadJob'
        }
    }

    Context "Appends multiple attempts" {
        BeforeAll {
            Clear-JSMJobAttempt
            Add-JSMJobAttempt -JobName 'MultiJob' -Attempt 1 -JobType PSJob
            Add-JSMJobAttempt -JobName 'MultiJob' -Attempt 2 -JobType PSJob
        }
        It "stores two attempt records for the same job" {
            @(Get-JSMJobAttempt -JobName 'MultiJob').Count | Should -Be 2
        }
    }
}
