$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'UnitTests' {
    BeforeAll {
        $JobDef1 = [pscustomobject]@{
            Name                 = 'Job1'
            DependsOnJobs        = @()
            JobFailureRetryLimit = 0
        }
        $JobDef2 = [pscustomobject]@{
            Name                 = 'Job2'
            DependsOnJobs        = @('Job1')
            JobFailureRetryLimit = 0
        }
        $JobDef3 = [pscustomobject]@{
            Name                 = 'Job3'
            DependsOnJobs        = @()
            JobFailureRetryLimit = 0
        }
        $AllJobs = @($JobDef1, $JobDef2, $JobDef3)
    }

    Context "Dependency resolution" {
        It "Returns jobs with no dependencies when nothing is running or completed" {
            $result = @(Get-JSMJobNext -JobCompletion @{} -JobCurrent @{} -JobRequired $AllJobs -JobFailure @{} -JobFailureRetryLimit 3)
            $result.Name | Should -Contain 'Job1'
            $result.Name | Should -Contain 'Job3'
            $result.Name | Should -Not -Contain 'Job2'
        }

        It "Returns Job2 when Job1 is completed" {
            $result = @(Get-JSMJobNext -JobCompletion @{Job1=$true} -JobCurrent @{} -JobRequired $AllJobs -JobFailure @{} -JobFailureRetryLimit 3)
            $result.Name | Should -Contain 'Job2'
            $result.Name | Should -Not -Contain 'Job1'
        }

        It "Does not return jobs that are already running" {
            $result = @(Get-JSMJobNext -JobCompletion @{} -JobCurrent @{Job1=$true} -JobRequired $AllJobs -JobFailure @{} -JobFailureRetryLimit 3)
            $result.Name | Should -Not -Contain 'Job1'
            $result.Name | Should -Contain 'Job3'
        }

        It "Does not return jobs that are already completed" {
            $result = @(Get-JSMJobNext -JobCompletion @{Job1=$true;Job3=$true} -JobCurrent @{} -JobRequired $AllJobs -JobFailure @{} -JobFailureRetryLimit 3)
            $result.Name | Should -Not -Contain 'Job1'
            $result.Name | Should -Not -Contain 'Job3'
            $result.Name | Should -Contain 'Job2'
        }
    }

    Context "Retry limit logic" {
        It "Does not return a job that has exceeded the global retry limit" {
            $failures = @{Job1 = [pscustomobject]@{FailureCount = 3}}
            $result = @(Get-JSMJobNext -JobCompletion @{} -JobCurrent @{} -JobRequired $AllJobs -JobFailure $failures -JobFailureRetryLimit 3)
            $result.Name | Should -Not -Contain 'Job1'
        }

        It "Returns a job that has NOT yet exceeded the global retry limit" {
            $failures = @{Job1 = [pscustomobject]@{FailureCount = 1}}
            $result = @(Get-JSMJobNext -JobCompletion @{} -JobCurrent @{} -JobRequired $AllJobs -JobFailure $failures -JobFailureRetryLimit 3)
            $result.Name | Should -Contain 'Job1'
        }
    }
}
