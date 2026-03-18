$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('PeriodicReportSetting', 'JobRequired', 'Stopwatch', 'JobCompletion',
                'StartJobSuccess', 'JobCurrent', 'JobPending', 'JobFailure', 'Interactive', 'FatalFailure')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Start-JSMStopwatch -Restart
        $script:SW = Get-JSMStopwatch
        $script:JobDef = [pscustomobject]@{ Name = 'TestJob' }
        $script:JobRequired = @{ TestJob = $script:JobDef }
        # Clear stopwatch period state
        & (Get-Module JobSetManager) {
            Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
        }
    }

    Context "Interactive mode does not throw" {
        It "runs without error when Interactive is true" {
            $started = [System.Collections.Generic.List[pscustomobject]]::new()
            {
                Start-JSMPeriodicReportProcess `
                    -PeriodicReportSetting $null `
                    -JobRequired $script:JobRequired `
                    -Stopwatch $script:SW `
                    -JobCompletion @{} `
                    -StartJobSuccess $started `
                    -JobCurrent @{} `
                    -JobPending @{TestJob = $true} `
                    -JobFailure @{} `
                    -Interactive $true `
                    -FatalFailure $false
            } | Should -Not -Throw
        }
        It "runs without error when FatalFailure is true" {
            $started = [System.Collections.Generic.List[pscustomobject]]::new()
            {
                Start-JSMPeriodicReportProcess `
                    -PeriodicReportSetting $null `
                    -JobRequired $script:JobRequired `
                    -Stopwatch $script:SW `
                    -JobCompletion @{} `
                    -StartJobSuccess $started `
                    -JobCurrent @{} `
                    -JobPending @{} `
                    -JobFailure @{TestJob = $true} `
                    -Interactive $true `
                    -FatalFailure $true
            } | Should -Not -Throw
        }
    }

    Context "Null PeriodicReportSetting does not throw" {
        It "runs without error when PeriodicReportSetting is null and Interactive is false" {
            $started = [System.Collections.Generic.List[pscustomobject]]::new()
            {
                Start-JSMPeriodicReportProcess `
                    -PeriodicReportSetting $null `
                    -JobRequired $script:JobRequired `
                    -Stopwatch $script:SW `
                    -JobCompletion @{} `
                    -StartJobSuccess $started `
                    -JobCurrent @{} `
                    -JobPending @{} `
                    -JobFailure @{} `
                    -Interactive $false `
                    -FatalFailure $false
            } | Should -Not -Throw
        }
    }

    Context "Periodic report evaluation with FirstTestTrue" {
        BeforeAll {
            & (Get-Module JobSetManager) { Initialize-TrackingVariable }
            & (Get-Module JobSetManager) {
                Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
            }
            $script:ReportSetting = Set-JSMPeriodicReportSetting -Units Seconds -Length 300 -SendEmail $false -FirstTestTrue $true
            $started = [System.Collections.Generic.List[pscustomobject]]::new()
        }
        AfterAll {
            & (Get-Module JobSetManager) { $Script:JSMPeriodicReportSetting = $null }
            & (Get-Module JobSetManager) {
                Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
            }
        }
        It "does not throw when PeriodicReportSetting is provided" {
            $started = [System.Collections.Generic.List[pscustomobject]]::new()
            {
                Start-JSMPeriodicReportProcess `
                    -PeriodicReportSetting $script:ReportSetting `
                    -JobRequired $script:JobRequired `
                    -Stopwatch $script:SW `
                    -JobCompletion @{} `
                    -StartJobSuccess $started `
                    -JobCurrent @{} `
                    -JobPending @{TestJob = $true} `
                    -JobFailure @{} `
                    -Interactive $false `
                    -FatalFailure $false
            } | Should -Not -Throw
        }
    }
}
