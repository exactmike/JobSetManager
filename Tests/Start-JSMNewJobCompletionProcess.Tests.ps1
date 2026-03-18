$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobCompletion', 'JobRequired', 'SuppressVariableRemoval')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
    }

    Context "Returns nothing when no jobs have completed" {
        It "returns nothing when no matching completed jobs exist" {
            $jobDef = [pscustomobject]@{
                Name                     = 'JSMNoCompletionJob'
                JobSplit                 = 1
                ResultsVariableName      = 'JSMNoCompletionResult'
                ResultsKeyVariableNames  = @()
                ResultsValidation        = @{}
                PostJobCommands          = $null
                RemoveVariablesAtCompletion = @()
            }
            $result = Start-JSMNewJobCompletionProcess -JobCompletion @{} -JobRequired @{JSMNoCompletionJob = $jobDef}
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Processes a successfully completed job" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobCompletion
            Clear-JSMProcessingStatusEntry
            Clear-JSMJobFailure

            $script:CompJobDef = [pscustomobject]@{
                Name                     = 'JSMCompletionTestJob'
                JobSplit                 = 1
                ResultsVariableName      = 'JSMCompletionTestResult'
                ResultsKeyVariableNames  = @()
                ResultsValidation        = @{}
                PostJobCommands          = $null
                RemoveVariablesAtCompletion = @()
            }
            $script:JobRequired = @{JSMCompletionTestJob = $script:CompJobDef}

            # Start and complete the job
            $null = Start-Job -Name 'JSMCompletionTestJob' -ScriptBlock { 'testresult' }
            Add-JSMJobAttempt -JobName 'JSMCompletionTestJob' -Attempt 1 -JobType PSJob
            $null = Get-Job -Name 'JSMCompletionTestJob' | Wait-Job -Timeout 30

            $script:Failures = @(Start-JSMNewJobCompletionProcess -JobCompletion @{} -JobRequired $script:JobRequired)
        }
        AfterAll {
            Clear-JSMJobAttempt
            Clear-JSMJobCompletion
            Clear-JSMProcessingStatusEntry
            Clear-JSMJobFailure
            Get-Job -Name 'JSMCompletionTestJob' -ErrorAction SilentlyContinue | Remove-Job -Force
            Remove-Variable -Name JSMCompletionTestResult -Scope Global -ErrorAction SilentlyContinue
        }

        It "returns no failure objects" {
            $script:Failures.Count | Should -Be 0
        }
        It "records the job as completed in JobCompletions" {
            (Get-JSMJobCompletion).ContainsKey('JSMCompletionTestJob') | Should -Be $true
        }
        It "assigns results to the configured global variable" {
            $global:JSMCompletionTestResult | Should -Be 'testresult'
        }
        It "removes the underlying PS job" {
            $job = Get-Job -Name 'JSMCompletionTestJob' -ErrorAction SilentlyContinue
            $job | Should -BeNullOrEmpty
        }
        It "marks the attempt as Complete" {
            $attempt = @(Get-JSMJobAttempt -JobName 'JSMCompletionTestJob')
            $attempt[0].StopType | Should -Be 'Complete'
        }
        It "logs a successful completion status entry" {
            $entries = @(Get-JSMProcessingStatusEntry | Where-Object { $_.JobName -eq 'JSMCompletionTestJob' -and $_.EventID -eq 498 })
            $entries.Count | Should -BeGreaterThan 0
        }
    }

    Context "Skips jobs already in JobCompletion" {
        BeforeAll {
            Clear-JSMJobAttempt
            Clear-JSMJobCompletion
            Clear-JSMProcessingStatusEntry
            $jobDef = [pscustomobject]@{
                Name                     = 'AlreadyDoneJob'
                JobSplit                 = 1
                ResultsVariableName      = 'AlreadyDoneResult'
                ResultsKeyVariableNames  = @()
                ResultsValidation        = @{}
                PostJobCommands          = $null
                RemoveVariablesAtCompletion = @()
            }
            $script:SkipResult = @(Start-JSMNewJobCompletionProcess `
                -JobCompletion @{AlreadyDoneJob = $true} `
                -JobRequired @{AlreadyDoneJob = $jobDef})
        }
        AfterAll {
            Clear-JSMJobAttempt; Clear-JSMJobCompletion; Clear-JSMProcessingStatusEntry
        }
        It "returns no failures for an already-completed job" {
            $script:SkipResult.Count | Should -Be 0
        }
    }
}
