$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")


Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    Context "Returns existing stopwatch" {
        BeforeAll {
            Start-JSMStopwatch -Restart
        }
        It "returns the script-scope stopwatch" {
            $result = Get-JSMStopwatch
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Diagnostics.Stopwatch]
        }
        It "returns a running stopwatch" {
            $result = Get-JSMStopwatch
            $result.IsRunning | Should -Be $true
        }
    }

    Context "Starts stopwatch if it does not exist" {
        BeforeAll {
            & (Get-Module JobSetManager) { Remove-Variable -Name Stopwatch -Scope Script -ErrorAction SilentlyContinue }
        }
        It "creates and returns a new stopwatch when none exists" {
            $result = Get-JSMStopwatch
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [System.Diagnostics.Stopwatch]
        }
        It "the newly created stopwatch is running" {
            $result = Get-JSMStopwatch
            $result.IsRunning | Should -Be $true
        }
    }
}
