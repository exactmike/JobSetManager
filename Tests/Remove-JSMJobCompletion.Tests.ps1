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
        Add-JSMJobCompletion -Name 'Job1'
        Add-JSMJobCompletion -Name 'Job2'
    }
    AfterAll {
        Clear-JSMJobCompletion
    }

    Context "Removes the specified entry" {
        BeforeAll {
            Remove-JSMJobCompletion -Name 'Job1'
        }
        It "removes the named job from JobCompletions" {
            (Get-JSMJobCompletion).ContainsKey('Job1') | Should -Be $false
        }
        It "leaves other entries intact" {
            (Get-JSMJobCompletion).ContainsKey('Job2') | Should -Be $true
        }
    }

    Context "Safe to remove a non-existent entry" {
        It "does not throw when the entry does not exist" {
            { Remove-JSMJobCompletion -Name 'NonExistentJob' } | Should -Not -Throw
        }
    }
}
