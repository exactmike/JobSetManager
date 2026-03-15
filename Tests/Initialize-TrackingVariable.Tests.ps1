$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'UnitTests' {
    # Initialize-TrackingVariable is a private function; invoke it in the module's scope
    BeforeAll {
        $module = Get-Module JobSetManager
    }

    Context "Initializes tracking variables idempotently" {
        BeforeAll {
            # Reset script-scope variables inside the module
            & $module {
                Remove-Variable -Name JobAttempts -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name JobCompletions -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name JobFailures -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name SplitJobGroups -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name JSMProcessingLoopStatus -Scope Script -ErrorAction SilentlyContinue
                Remove-Variable -Name JSMProcessingStatusEntryID -Scope Script -ErrorAction SilentlyContinue
                Initialize-TrackingVariable
            }
        }

        It "Creates the JobAttempts collection" {
            $result = & $module { $null -ne $script:JobAttempts }
            $result | Should -Be $true
        }

        It "Creates the JobCompletions hashtable" {
            $result = & $module { $script:JobCompletions -is [hashtable] }
            $result | Should -Be $true
        }

        It "Creates the JobFailures hashtable" {
            $result = & $module { $script:JobFailures -is [hashtable] }
            $result | Should -Be $true
        }

        It "Creates the SplitJobGroups hashtable" {
            $result = & $module { $script:SplitJobGroups -is [hashtable] }
            $result | Should -Be $true
        }

        It "Creates the JSMProcessingLoopStatus collection" {
            $result = & $module { $null -ne $script:JSMProcessingLoopStatus }
            $result | Should -Be $true
        }

        It "Initializes JSMProcessingStatusEntryID to 0" {
            $result = & $module { $script:JSMProcessingStatusEntryID }
            $result | Should -Be 0
        }
    }

    Context "Does not overwrite existing tracking data (idempotent)" {
        BeforeAll {
            Add-JSMJobAttempt -JobName 'IdempotentTestJob' -Attempt 1 -JobType PSJob | Out-Null
            $countBefore = @(Get-JSMJobAttempt).Count
            & $module { Initialize-TrackingVariable }
            $countAfter = @(Get-JSMJobAttempt).Count
        }
        AfterAll {
            Clear-JSMJobAttempt
        }

        It "Does not reset JobAttempts when called again" {
            $countAfter | Should -Be $countBefore
        }
    }
}
