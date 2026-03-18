$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Restart')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeEach {
        # Remove the stopwatch before each test for isolation
        & (Get-Module JobSetManager) { Remove-Variable -Name Stopwatch -Scope Script -ErrorAction SilentlyContinue }
    }

    Context "Creates and starts a new stopwatch" {
        It "creates the script-scope Stopwatch variable" {
            Start-JSMStopwatch
            $sw = & (Get-Module JobSetManager) { $script:Stopwatch }
            $sw | Should -Not -BeNullOrEmpty
        }
        It "creates a running Stopwatch instance" {
            Start-JSMStopwatch
            $sw = & (Get-Module JobSetManager) { $script:Stopwatch }
            $sw | Should -BeOfType [System.Diagnostics.Stopwatch]
            $sw.IsRunning | Should -Be $true
        }
    }

    Context "Does not restart if already running (no -Restart)" {
        It "preserves the existing stopwatch when called without -Restart" {
            Start-JSMStopwatch
            $sw1 = & (Get-Module JobSetManager) { $script:Stopwatch }
            Start-Sleep -Milliseconds 10
            Start-JSMStopwatch
            $sw2 = & (Get-Module JobSetManager) { $script:Stopwatch }
            # Same object reference — not recreated
            [object]::ReferenceEquals($sw1, $sw2) | Should -Be $true
        }
    }

    Context "Restarts when -Restart is specified" {
        It "creates a new stopwatch with -Restart" {
            Start-JSMStopwatch
            $sw1 = & (Get-Module JobSetManager) { $script:Stopwatch }
            Start-Sleep -Milliseconds 10
            Start-JSMStopwatch -Restart
            $sw2 = & (Get-Module JobSetManager) { $script:Stopwatch }
            # A new stopwatch should have less elapsed time than the original
            $sw2.Elapsed | Should -BeLessOrEqual $sw1.Elapsed
        }
    }
}
