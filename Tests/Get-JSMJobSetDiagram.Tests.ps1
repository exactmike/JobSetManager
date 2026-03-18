$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobSet', 'Progress', 'JobCompletion', 'JobCurrent', 'JobFailure')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }

    Context "Behavior when PSGraph is not installed" {
        BeforeAll {
            $script:JobDef = [pscustomobject]@{
                Name          = 'TestJob'
                JobSplit      = 1
                DependsOnJobs = @()
            }
        }
        It "does not throw in Static mode when PSGraph is not available" {
            { Get-JSMJobSetDiagram -JobSet @($script:JobDef) -WarningAction SilentlyContinue } | Should -Not -Throw
        }
        It "writes a warning when PSGraph is not available" {
            if (Get-Command 'graph' -ErrorAction SilentlyContinue) {
                Set-ItResult -Skipped -Because 'PSGraph is installed'
            }
            $warnings = @()
            Get-JSMJobSetDiagram -JobSet @($script:JobDef) -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings.Count | Should -BeGreaterThan 0
        }
        It "does not throw in Progress mode when PSGraph is not available" {
            {
                Get-JSMJobSetDiagram -JobSet @($script:JobDef) -Progress `
                    -JobCompletion @{} -JobCurrent @{} -JobFailure @{} -WarningAction SilentlyContinue
            } | Should -Not -Throw
        }
    }
}
