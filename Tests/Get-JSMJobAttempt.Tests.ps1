$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobName','Attempt','Active','JobType','StopType')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        Clear-JSMJobAttempt
        Add-JSMJobAttempt -JobName GetTheThings -Attempt 1 -JobType PSJob
        Add-JSMJobAttempt -JobName GetTheOtherThings -Attempt 1 -JobType PSJob
        Set-JSMJobAttempt -JobName GetTheThings -Attempt 1 -StopType Fail
        Add-JSMJobAttempt -JobName GetTheThings -Attempt 2
    }
    AfterAll {
        Clear-JSMJobAttempt
    }
    Context "Gets Entries Per Specified Parameters" {
        It "returns all entries when used with no parameters" {
            $Entries = @(Get-JSMJobAttempt)
            $Entries.count | Should -Be 3
            $Entries[0].JobName | Should -Be 'GetTheThings'
            $Entries[1].JobName | Should -Be 'GetTheOtherThings'
            $Entries[-1].JobName | Should -Be 'GetTheThings'
        }
        It "Gets entries for the specified JobName" {
            $Entries = @(Get-JSMJobAttempt -JobName 'GetTheThings')
            $Entries.count | Should -Be 2
            $Entries[0].JobName | Should -Be 'GetTheThings'
            $Entries[1].JobName | Should -Be 'GetTheThings'
            $Entries[-1].JobName | Should -Be 'GetTheThings'
        }
        It "Gets only the active entry for a specified JobName" {
            $Entries = @(Get-JSMJobAttempt -JobName 'GetTheThings' -Active $true)
            $Entries.count | Should -Be 1
            $Entries[0].JobName | Should -Be 'GetTheThings'
            $Entries[0].Active | Should -Be $True
        }
        It "Gets only the specified Attempt(s) when Attempt(s) are specified" {
            $Entries = @(Get-JSMJobAttempt -Attempt 1)
            $Entries.count | Should -Be 2
            $Entries[0].JobName | Should -Be 'GetTheThings'
            $Entries[1].JobName | Should -Be 'GetTheOtherThings'
            $Entries[0].Attempt | Should -Be 1
            $Entries[1].Attempt | Should -Be 1
        }
        It "Gets only the matching Active Attempt(s) when Active is specified" {
            $Entries = @(Get-JSMJobAttempt -Active $false)
            $Entries.count | Should -Be 1
            $Entries[0].JobName | Should -Be 'GetTheThings'
            $Entries[0].Active | Should -Be $false
            $Entries[0].Stop | Should -BeOfType [DateTime]
        }
    }
}
