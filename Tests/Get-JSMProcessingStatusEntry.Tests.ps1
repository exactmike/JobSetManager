$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('EntryID','JobName')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        Clear-JSMProcessingStatusEntry
        Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Message1' -Status $true -EventID 102
        Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Message2' -Status $false -EventID 101
        Add-JSMProcessingStatusEntry -JobName 'Job3' -Message 'Message3' -Status $true -EventID 301
        Add-JSMProcessingStatusEntry -JobName 'Job3' -Message 'Message3' -Status $false -EventID 01
    }
    Context "Gets the expected entry(ies)" {
        It "Gets all entries when run with no parameters" {
            $Entries = Get-JSMProcessingStatusEntry
            $Entries.Count | Should -Be 4
            ($Entries.EntryID | Select-Object -Unique).Count | Should -Be 4
            $Entries[0].EntryID | Should -Be 1
            $Entries[-1].EntryID | Should -Be 4
            $Entries.JobName | Should -Contain 'Job1'
            $Entries.JobName | Should -Contain 'Job3'
        }

        It "Gets the entry(ies) for a specified Job" {
            $Entries = Get-JSMProcessingStatusEntry -JobName 'Job1'
            $Entries.Count | Should -Be 2
            ($Entries.JobName | Select-Object -Unique).Count | Should -Be 1
            $Entries[0].JobName | Should -BeExactly 'Job1'
        }

        It "Gets entries for multiple specified Jobs" {
            $Entries = Get-JSMProcessingStatusEntry -JobName 'Job1','Job3'
            $Entries.Count | Should -Be 4
            ($Entries.JobName | Select-Object -Unique).Count | Should -Be 2
            $Entries[0].JobName | Should -BeExactly 'Job1'
            $Entries[-1].JobName | Should -BeExactly 'Job3'
        }

        It "Gets the entry for a specified EntryID" {
            $Entries = @(Get-JSMProcessingStatusEntry -EntryID 2)
            $Entries.Count | Should -Be 1
            $Entries.EntryID | Should -Be 2
        }

        It "Gets entries for multiple specified EntryIDs" {
            $Entries = Get-JSMProcessingStatusEntry -EntryID 2,4
            $Entries.Count | Should -Be 2
            ($Entries.EntryID | Select-Object -Unique).Count | Should -Be 2
            $Entries[0].EntryID | Should -Be 2
            $Entries[-1].EntryID | Should -Be 4
        }
    }
}

Describe "$commandname Example Tests" -Tags "Example" {
    Context "Example 1 Gets Entries as expected" {
        BeforeAll {
            Clear-JSMProcessingStatusEntry
            Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Message1' -Status $true  -EventID 102
            Add-JSMProcessingStatusEntry -JobName 'Job1' -Message 'Message2' -Status $false  -EventID 101
            Add-JSMProcessingStatusEntry -JobName 'job3' -Message 'Message3' -Status $true -EventID 302
            Add-JSMProcessingStatusEntry -JobName 'job3' -Message 'Message3' -Status $false -EventID 501
        }
        It "Gets all entries when run with no parameters" {
            $Entries = Get-JSMProcessingStatusEntry
            $Entries.Count | Should -Be 4
            ($Entries.EntryID | Select-Object -Unique).Count | Should -Be 4
            $Entries[0].EntryID | Should -Be 1
            $Entries[-1].EntryID | Should -Be 4
            $Entries.JobName | Should -Contain 'Job1'
            $Entries.JobName | Should -Contain 'job3'
        }
    }
}
