$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    Context "Simple 2-job dependency chain completes successfully" {
        BeforeAll {
            $JobDefinitions = @(
                [pscustomobject]@{
                    Name                      = 'LoopTestJob1'
                    PreJobCommands            = $null
                    StartJobParams            = @{
                        ScriptBlock = { @(1,2,3) }
                    }
                    ArgumentList              = @()
                    JobSplit                  = 1
                    JobSplitDataVariableName  = $null
                    DependsOnJobs             = @()
                    OnCondition               = @()
                    OnNotCondition            = @()
                    ResultsVariableName       = 'LoopTestJob1Result'
                    ResultsKeyVariableNames   = @()
                    ResultsValidation         = @{ ValidateType = [array] }
                    RemoveVariablesAtCompletion = @()
                    PostJobCommands           = $null
                    JobFailureRetryLimit      = 0
                },
                [pscustomobject]@{
                    Name                      = 'LoopTestJob2'
                    PreJobCommands            = $null
                    StartJobParams            = @{
                        ScriptBlock = { $using:LoopTestJob1Result | Measure-Object -Sum }
                    }
                    ArgumentList              = @()
                    JobSplit                  = 1
                    JobSplitDataVariableName  = $null
                    DependsOnJobs             = @('LoopTestJob1')
                    OnCondition               = @()
                    OnNotCondition            = @()
                    ResultsVariableName       = 'LoopTestJob2Result'
                    ResultsKeyVariableNames   = @()
                    ResultsValidation         = @{}
                    RemoveVariablesAtCompletion = @()
                    PostJobCommands           = $null
                    JobFailureRetryLimit      = 0
                }
            )
            # Run the loop with a short sleep and LoopOnce to avoid blocking tests long
            $loopResult = Invoke-JSMProcessingLoop -JobDefinition $JobDefinitions -SleepSecondsBetweenJobCheck 5 -JobType PSJob
        }
        AfterAll {
            Remove-Variable -Name LoopTestJob1Result -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name LoopTestJob2Result -Scope Global -ErrorAction SilentlyContinue
            Get-Job -Name 'LoopTestJob*' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
            Clear-JSMJobAttempt
            Clear-JSMJobCompletion
        }

        It "Returns true (no fatal failure)" {
            $loopResult | Should -Be $true
        }

        It "Produces output from Job1" {
            $global:LoopTestJob1Result | Should -Not -BeNullOrEmpty
        }

        It "Job1 result contains at least one item" {
            @($global:LoopTestJob1Result).Count | Should -BeGreaterOrEqual 1
        }
    }
}
