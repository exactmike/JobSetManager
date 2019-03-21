$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
        $knownParameters = @()
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
        Add-JSMJobAttempt -JobName GetTheOtherOtherThings -Attempt 1 -JobType RSJob
        Set-JSMJobAttempt -JobName GetTheThings -Attempt 1 -StopType Fail
        #Add-JSMJobAttempt -JobName GetTheThings -Attempt 2
    }
    AfterAll {
        Clear-JSMJobAttempt
    }
    Context "Gets Active JSM Job Attempts" {
        $Entries = @(Get-JSMJobCurrent)
        It "returns all entries when used with no parameters" {
            $Entries.count | Should Be 2
            $Entries[0].JobName | Should Be 'GetTheOtherThings'
            $Entries[1].JobName | Should Be 'GetTheOtherOtherThings'
            $Entries[-1].JobName | Should Be 'GetTheOtherOtherThings'
        }
    }
}