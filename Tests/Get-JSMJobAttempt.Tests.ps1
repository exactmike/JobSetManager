$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
        $knownParameters = 'JobName','Attempt','Active','JobType','StopType'
        $paramCount = $knownParameters.Count
        It "Should contain specific parameters" {
            ( (Compare-Object -ReferenceObject $knownParameters -DifferenceObject $params -IncludeEqual | Where-Object SideIndicator -eq "==").Count ) | Should Be $paramCount
        }
        It "Should only contain $paramCount parameters" {
            $params.Count - $defaultParamCount | Should Be $paramCount
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        Clear-JSMJobAttempt
        Add-JSMJobAttempt -JobName GetTheThings -Attempt 1 -JobType RSJob
        Add-JSMJobAttempt -JobName GetTheOtherThings -Attempt 1 -JobType RSJob
        Set-JSMJobAttempt -JobName GetTheThings -Attempt 1 -StopType Fail
        Add-JSMJobAttempt -JobName GetTheThings -Attempt 2
    }
    AfterAll {
        Clear-JSMJobAttempt
    }
    Context "Gets Entries Per Specified Parameters" {
        $Entries = @(Get-JSMJobAttempt)
        It "returns all entries when used with no parameters" {
            $Entries.count | Should Be 3
            $Entries[0].JobName | Should Be 'GetTheThings'
            $Entries[1].JobName | Should Be 'GetTheOtherThings'
            $Entries[-1].JobName | Should Be 'GetTheThings'
        }
        $Entries = @(Get-JSMJobAttempt -JobName 'GetTheThings')
        It "Gets entries for the specified JobName" {
            $Entries.count | Should Be 2
            $Entries[0].JobName | Should Be 'GetTheThings'
            $Entries[1].JobName | Should Be 'GetTheThings'
            $Entries[-1].JobName | Should Be 'GetTheThings'
        }
        $Entries = @(Get-JSMJobAttempt -JobName 'GetTheThings' -Active $true)
        It "Gets only the active entry for a specified JobName" {
            $Entries.count | Should Be 1
            $Entries[0].JobName | Should Be 'GetTheThings'
            $entries[0].Active | Should Be $True
        }
        $Entries = @(Get-JSMJobAttempt -Attempt 1)
        It "Gets only the specified Attempt(s) when Attempt(s) are specified" {
            $Entries.count | Should Be 2
            $Entries[0].JobName | Should Be 'GetTheThings'
            $Entries[1].JobName | Should Be 'GetTheOtherThings'
            $Entries[0].Attempt | Should Be 1
            $Entries[1].Attempt | Should Be 1
        }
        $Entries = @(Get-JSMJobAttempt -Active $false)
        It "Gets only the matching Acive Attempt(s) when Active is specified" {
            $Entries.count | Should Be 1
            $Entries[0].JobName | Should Be 'GetTheThings'
            $Entries[0].Active | Should Be $false
            $Entries[0].Stop | Should BeOfType [DateTime]
        }
    }
}