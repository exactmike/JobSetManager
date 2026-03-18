$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobRequired')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        Clear-JSMJobCompletion
        $script:JobDef1 = [pscustomobject]@{ Name = 'PendingJob1' }
        $script:JobDef2 = [pscustomobject]@{ Name = 'PendingJob2' }
        $script:JobDef3 = [pscustomobject]@{ Name = 'PendingJob3' }
        $script:AllJobs = @{
            PendingJob1 = $script:JobDef1
            PendingJob2 = $script:JobDef2
            PendingJob3 = $script:JobDef3
        }
    }
    AfterAll {
        Clear-JSMJobCompletion
    }

    Context "All jobs pending when nothing running or completed" {
        It "returns all required jobs as pending" {
            Clear-JSMJobCompletion
            $result = Get-JSMJobPending -JobRequired $script:AllJobs
            $result | Should -BeOfType [hashtable]
            $result.ContainsKey('PendingJob1') | Should -Be $true
            $result.ContainsKey('PendingJob2') | Should -Be $true
            $result.ContainsKey('PendingJob3') | Should -Be $true
        }
    }

    Context "Excludes completed jobs" {
        BeforeAll {
            Clear-JSMJobCompletion
            Add-JSMJobCompletion -Name 'PendingJob1'
        }
        AfterAll {
            Clear-JSMJobCompletion
        }
        It "excludes the completed job from pending" {
            $result = Get-JSMJobPending -JobRequired $script:AllJobs
            $result.ContainsKey('PendingJob1') | Should -Be $false
        }
        It "still includes other pending jobs" {
            $result = Get-JSMJobPending -JobRequired $script:AllJobs
            $result.ContainsKey('PendingJob2') | Should -Be $true
            $result.ContainsKey('PendingJob3') | Should -Be $true
        }
    }

    Context "Returns empty hashtable when all jobs are completed" {
        BeforeAll {
            Clear-JSMJobCompletion
            Add-JSMJobCompletion -Name 'PendingJob1'
            Add-JSMJobCompletion -Name 'PendingJob2'
            Add-JSMJobCompletion -Name 'PendingJob3'
        }
        AfterAll {
            Clear-JSMJobCompletion
        }
        It "returns an empty hashtable" {
            $result = Get-JSMJobPending -JobRequired $script:AllJobs
            $result.Count | Should -Be 0
        }
    }
}
