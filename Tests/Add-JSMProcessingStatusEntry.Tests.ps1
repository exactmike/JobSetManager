$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        $defaultParamCount = 11
        [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
        $knownParameters = 'JobName','Message','Status','EventID','PassThru'
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
    Context "Adds the correct Entry" {
        $Entry = Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Doing Something with or to Job1' -Status $true -PassThru -EventID 102
        It "sets the correct JobName" {
            $Entry.JobName | Should BeExactly 'Job1'
        }

        It "sets the correct message" {
            $Entry.Message | Should BeExactly 'Doing Something with or to Job1'
        }

        It "sets the correct status" {
            $Entry.status | Should Be $true
        }

        It "Increments and sets EntryID" {
            $NextEntry = Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Doing Something with or to Job1' -Status $false -PassThru -EventID 101
            ($NextEntry.EntryID - $Entry.EntryID) -eq 1 | Should Be $true
        }
    }
}

Describe "$commandname Example Tests" -Tags "Example" {
    Context "Adds the Correct Entry" {
        $AddEntry = Add-JSMProcessingStatusEntry -JobName GetUsers -Message 'Ready to start' -Status $true -PassThru -EventID 102
        $NewEntry = Get-JSMProcessingStatusEntry -EntryID $AddEntry.EntryID
        It "creates the correct Entry which is retrievable by Get-JSMProcessingStatusEntry" {
            Compare-Object -ReferenceObject $AddEntry -DifferenceObject $NewEntry | Should Be $null
        }
    }
}