$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
        $knownParameters = 'JobName','Message','Status','PassThru'
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
    Context "entry is correctly made and returned" {
        $Entry = New-JSMProcessingLoopStatusEntry -JobName 'Job1' -Message 'Doing Something with or to Job1' -Status $true -PassThru
        It "returns the correct JobName" {
            $Entry.JobName | Should BeExactly 'Job1'
        }

        It "returns the correct message" {
            $Entry.Message | Should BeExactly 'Doing Something with or to Job1'
        }

        It "returns the correct status" {
            $Entry.status | Should Be $true
        }

        It "Increments and returns the EntryID" {
            $NextEntry = New-JSMProcessingLoopStatusEntry -JobName 'Job1' -Message 'Doing Something with or to Job1' -Status $false -PassThru
            $Entry.EntryID -lt $NextEntry.EntryID | Should Be $true
        }
    }
}