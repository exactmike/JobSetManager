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
        Clear-JSMJobCompletion
    }
    AfterAll {
        Clear-JSMJobCompletion
    }

    Context "Adds completion entry" {
        BeforeAll {
            Add-JSMJobCompletion -Name 'CompletedJob1'
        }
        It "adds the job name as a key in JobCompletions" {
            (Get-JSMJobCompletion).ContainsKey('CompletedJob1') | Should -Be $true
        }
        It "sets the value to true" {
            (Get-JSMJobCompletion)['CompletedJob1'] | Should -Be $true
        }
    }

    Context "Adding multiple entries" {
        BeforeAll {
            Clear-JSMJobCompletion
            Add-JSMJobCompletion -Name 'Job1'
            Add-JSMJobCompletion -Name 'Job2'
        }
        It "both entries are present" {
            $completions = Get-JSMJobCompletion
            $completions.ContainsKey('Job1') | Should -Be $true
            $completions.ContainsKey('Job2') | Should -Be $true
        }
        It "does not affect unrelated entries when adding a third" {
            Add-JSMJobCompletion -Name 'Job3'
            (Get-JSMJobCompletion).ContainsKey('Job1') | Should -Be $true
        }
    }
}
