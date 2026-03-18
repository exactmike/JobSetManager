$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobRequired', 'JobCompletion')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
    }
    AfterAll {
        Get-Job -Name 'JSMCurrentTest*' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job -Force
    }

    Context "Returns empty hashtable when no jobs match" {
        It "returns empty hashtable when JobRequired is empty" {
            $result = Get-JSMJobCurrent -JobRequired @{} -JobCompletion @{}
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }

    Context "Excludes jobs already in JobCompletion" {
        It "does not include a job that is already completed" {
            $jobDef = [pscustomobject]@{ Name = 'JSMCurrentTestCompleted' }
            $result = Get-JSMJobCurrent -JobRequired @{JSMCurrentTestCompleted = $jobDef} -JobCompletion @{JSMCurrentTestCompleted = $true}
            $result.ContainsKey('JSMCurrentTestCompleted') | Should -Be $false
        }
    }

    Context "Detects a running job" {
        BeforeAll {
            $script:RunningJob = Start-Job -Name 'JSMCurrentTestRunning' -ScriptBlock { Start-Sleep -Seconds 60 }
            $jobDef = [pscustomobject]@{ Name = 'JSMCurrentTestRunning' }
            $script:CurrentResult = Get-JSMJobCurrent -JobRequired @{JSMCurrentTestRunning = $jobDef} -JobCompletion @{}
        }
        AfterAll {
            Get-Job -Name 'JSMCurrentTestRunning' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job -Force
        }
        It "includes the running job in the result" {
            $script:CurrentResult.ContainsKey('JSMCurrentTestRunning') | Should -Be $true
        }
        It "returns a hashtable" {
            $script:CurrentResult | Should -BeOfType [hashtable]
        }
    }
}
