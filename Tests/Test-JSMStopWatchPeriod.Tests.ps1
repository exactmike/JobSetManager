$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Units', 'Stopwatch', 'Length', 'FirstTestTrue', 'MissedIntervalTrue', 'Reset')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Start-JSMStopwatch -Restart
        $script:SW = Get-JSMStopwatch
        # Clear tracking state
        & (Get-Module JobSetManager) {
            Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
        }
    }
    AfterAll {
        & (Get-Module JobSetManager) {
            Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
        }
    }

    Context "FirstTestTrue behavior" {
        BeforeAll {
            # Reset state for clean first-call test
            & (Get-Module JobSetManager) {
                Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
            }
        }
        It "returns true on the first call when -FirstTestTrue is specified" {
            $result = Test-JSMStopWatchPeriod -Units Seconds -Stopwatch $script:SW -Length 60 -FirstTestTrue
            $result | Should -Be $true
        }
        It "returns false on subsequent calls within the interval (no FirstTestTrue)" {
            $result = Test-JSMStopWatchPeriod -Units Seconds -Stopwatch $script:SW -Length 60
            $result | Should -Be $false
        }
    }

    Context "Reset behavior" {
        BeforeAll {
            # Consume the first-test
            & (Get-Module JobSetManager) {
                Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
            }
            $null = Test-JSMStopWatchPeriod -Units Seconds -Stopwatch $script:SW -Length 60 -FirstTestTrue
        }
        It "returns true again after Reset is specified" {
            $result = Test-JSMStopWatchPeriod -Units Seconds -Stopwatch $script:SW -Length 60 -FirstTestTrue -Reset
            $result | Should -Be $true
        }
    }

    Context "Normal interval detection with milliseconds" {
        BeforeAll {
            # Use a fresh stopwatch that has elapsed > 1ms (virtually guaranteed)
            $script:MsSW = [System.Diagnostics.Stopwatch]::StartNew()
            Start-Sleep -Milliseconds 5
            & (Get-Module JobSetManager) {
                Remove-Variable -Name LastUnits -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name FirstStopWatchPeriodTest -Scope Script -ErrorAction SilentlyContinue
            }
        }
        It "returns true when a full millisecond interval has elapsed" {
            $result = Test-JSMStopWatchPeriod -Units Milliseconds -Stopwatch $script:MsSW -Length 1
            $result | Should -Be $true
        }
    }

    Context "MissedIntervalTrue behavior" {
        BeforeAll {
            $script:SlowSW = [System.Diagnostics.Stopwatch]::StartNew()
            Start-Sleep -Milliseconds 20
            & (Get-Module JobSetManager) {
                $script:LastUnits = 0
                $script:FirstStopWatchPeriodTest = $false
            }
        }
        It "returns true when an interval was missed and -MissedIntervalTrue is specified" {
            # At ~20ms, Length=5 -> currentUnits=20, (LastUnits=0 + Length=5) < currentUnits -> missed
            $result = Test-JSMStopWatchPeriod -Units Milliseconds -Stopwatch $script:SlowSW -Length 5 -MissedIntervalTrue
            $result | Should -Be $true
        }
    }
}
