$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Tests" -Tag 'UnitTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { Initialize-TrackingVariable }
        $script:Job1 = [pscustomobject]@{ Name = 'Job1'; OnCondition = @(); OnNOTCondition = @() }
        $script:Job2 = [pscustomobject]@{ Name = 'Job2'; OnCondition = @('FeatureEnabled'); OnNOTCondition = @() }
        $script:Job3 = [pscustomobject]@{ Name = 'Job3'; OnCondition = @(); OnNOTCondition = @('SkipOptional') }
    }
    AfterAll {
        Clear-JSMProcessingStatusEntry
    }

    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('Condition', 'JobDefinition')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }

    Context "No condition filter" {
        It "returns all job definitions when no Condition is specified" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job1, $script:Job2, $script:Job3)
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 3
            $result.ContainsKey('Job1') | Should -Be $true
            $result.ContainsKey('Job2') | Should -Be $true
            $result.ContainsKey('Job3') | Should -Be $true
        }
        It "returns hashtable keyed by job name" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job1)
            $result['Job1'].Name | Should -Be 'Job1'
        }
    }

    Context "OnCondition filtering" {
        It "includes jobs with empty OnCondition regardless of condition" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job1) -Condition @{FeatureEnabled = $false}
            $result.ContainsKey('Job1') | Should -Be $true
        }
        It "includes jobs whose OnCondition is satisfied" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job2) -Condition @{FeatureEnabled = $true}
            $result.ContainsKey('Job2') | Should -Be $true
        }
        It "excludes jobs whose OnCondition is not satisfied" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job2) -Condition @{FeatureEnabled = $false}
            $result | Should -BeNullOrEmpty
        }
    }

    Context "OnNOTCondition filtering" {
        It "excludes jobs whose OnNOTCondition is true" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job1, $script:Job3) -Condition @{SkipOptional = $true}
            $result.ContainsKey('Job3') | Should -Be $false
            $result.ContainsKey('Job1') | Should -Be $true
        }
        It "includes jobs whose OnNOTCondition is false" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job3) -Condition @{SkipOptional = $false}
            $result.ContainsKey('Job3') | Should -Be $true
        }
    }

    Context "Returns null when no jobs qualify" {
        It "returns null when all jobs are filtered out" {
            $result = Get-JSMJobRequired -JobDefinition @($script:Job2) -Condition @{FeatureEnabled = $false}
            $result | Should -BeNullOrEmpty
        }
    }
}
