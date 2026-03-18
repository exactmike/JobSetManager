$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('JobName', 'EntryID')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        Clear-JSMProcessingStatusEntry
        Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 started' -Status $true -EventID 100
        Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 failed' -Status $false -EventID 427
        Add-JSMProcessingStatusEntry -JobName 'Job2' -Message 'Job2 started' -Status $true -EventID 100
    }
    AfterAll {
        Clear-JSMProcessingStatusEntry
    }

    Context "All parameter set" {
        It "clears all status entries and resets the entry ID counter" {
            Clear-JSMProcessingStatusEntry
            @(Get-JSMProcessingStatusEntry).Count | Should -Be 0
            & (Get-Module JobSetManager) { $script:JSMProcessingStatusEntryID } | Should -Be 0
        }
    }

    Context "SpecificJob parameter set" {
        BeforeAll {
            Clear-JSMProcessingStatusEntry
            Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 started' -Status $true -EventID 100
            Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 failed' -Status $false -EventID 427
            Add-JSMProcessingStatusEntry -JobName 'Job2' -Message 'Job2 started' -Status $true -EventID 100
            Clear-JSMProcessingStatusEntry -JobName 'Job1'
        }
        It "removes all entries for the specified job" {
            @(Get-JSMProcessingStatusEntry -JobName 'Job1').Count | Should -Be 0
        }
        It "leaves entries for other jobs intact" {
            @(Get-JSMProcessingStatusEntry -JobName 'Job2').Count | Should -Be 1
        }
        It "does not reset the entry ID counter" {
            & (Get-Module JobSetManager) { $script:JSMProcessingStatusEntryID } | Should -BeGreaterThan 0
        }
        It "does not error when the job has no entries" {
            { Clear-JSMProcessingStatusEntry -JobName 'NonExistentJob' } | Should -Not -Throw
        }
    }

    Context "SpecificEntryID parameter set" {
        BeforeAll {
            Clear-JSMProcessingStatusEntry
            $script:Entry1 = Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 started' -Status $true -EventID 100 -PassThru
            $script:Entry2 = Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Job1 failed' -Status $false -EventID 427 -PassThru
            $script:Entry3 = Add-JSMProcessingStatusEntry -JobName 'Job2' -Message 'Job2 started' -Status $true -EventID 100 -PassThru
            Clear-JSMProcessingStatusEntry -EntryID $script:Entry1.EntryID,$script:Entry2.EntryID
        }
        It "removes only the specified entries" {
            @(Get-JSMProcessingStatusEntry).Count | Should -Be 1
        }
        It "the remaining entry is the one not targeted" {
            @(Get-JSMProcessingStatusEntry)[0].EntryID | Should -Be $script:Entry3.EntryID
        }
        It "does not reset the entry ID counter" {
            & (Get-Module JobSetManager) { $script:JSMProcessingStatusEntryID } | Should -BeGreaterThan 0
        }
        It "does not error when the specified EntryID does not exist" {
            { Clear-JSMProcessingStatusEntry -EntryID 99999 } | Should -Not -Throw
        }
    }
}
