$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        $module = Get-Module JobSetManager
        & $module { Initialize-TrackingVariable }
    }
    AfterAll {
        Clear-JSMJobAttempt
        # Clean up any test jobs
        Get-Job -Name 'JSMTestJob*' -ErrorAction SilentlyContinue | Remove-Job -Force
    }

    Context "Starts a simple PSJob" {
        BeforeAll {
            $JobDef = [pscustomobject]@{
                Name                      = 'JSMTestJobSimple'
                PreJobCommands            = $null
                StartJobParams            = @{
                    ScriptBlock = { 'result' }
                }
                ArgumentList              = @()
                JobSplit                  = 1
                JobSplitDataVariableName  = $null
            }
            $result = Start-JSMJob -Job @($JobDef) -JobType PSJob
        }
        AfterAll {
            Get-Job -Name 'JSMTestJobSimple' -ErrorAction SilentlyContinue | Remove-Job -Force
            Set-JSMJobAttempt -JobName 'JSMTestJobSimple' -Attempt 1 -StopType Complete
        }

        It "Returns a result hashtable with SuccessStartJobs" {
            $result.SuccessStartJobs | Should -Not -BeNullOrEmpty
        }

        It "Records a job attempt" {
            $attempts = @(Get-JSMJobAttempt -JobName 'JSMTestJobSimple')
            $attempts.Count | Should -BeGreaterOrEqual 1
        }

        It "Creates an actual PS job" {
            $job = Get-Job -Name 'JSMTestJobSimple' -ErrorAction SilentlyContinue
            $job | Should -Not -BeNullOrEmpty
        }
    }

    Context "Creates split sub-jobs and tracks in SplitJobGroups" {
        BeforeAll {
            $global:JSMTestSplitData = @(1,2,3,4)
            $JobDef = [pscustomobject]@{
                Name                      = 'JSMTestJobSplit'
                PreJobCommands            = $null
                StartJobParams            = @{
                    ScriptBlock = { param($splitData) $using:YourSplitData }
                }
                ArgumentList              = @()
                JobSplit                  = 2
                JobSplitDataVariableName  = 'JSMTestSplitData'
            }
            $result = Start-JSMJob -Job @($JobDef) -JobType PSJob
        }
        AfterAll {
            Get-Job | Where-Object { $_.Name -like 'JSMTestJobSplit_JSMPart_*' } | Remove-Job -Force
            Set-JSMJobAttempt -JobName 'JSMTestJobSplit' -Attempt 1 -StopType Complete
            Remove-Variable -Name JSMTestSplitData -Scope Global -ErrorAction SilentlyContinue
        }

        It "Returns success for split job" {
            $result.SuccessStartJobs | Should -Not -BeNullOrEmpty
        }

        It "Registers sub-job names in SplitJobGroups" {
            $splitGroups = & (Get-Module JobSetManager) { $script:SplitJobGroups }
            $splitGroups.ContainsKey('JSMTestJobSplit') | Should -Be $true
            $splitGroups['JSMTestJobSplit'].Count | Should -Be 2
        }

        It "Creates actual sub-jobs named with _JSMPart_ pattern" {
            $subJobs = Get-Job | Where-Object { $_.Name -like 'JSMTestJobSplit_JSMPart_*' }
            $subJobs.Count | Should -Be 2
        }
    }
}
