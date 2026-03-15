$ModuleName = 'JobSetManager'
$ModuleRoot = Split-Path (Split-Path -Path $PSCommandPath -Parent) -Parent

BeforeDiscovery {
    $rulesPath = Join-Path $ModuleRoot 'ScriptAnalyzerSettings.psd1'

    Import-Module (Join-Path $ModuleRoot 'JobSetManager.psd1') -Force

    $ScriptsForAnalysis = Get-ChildItem -Path (Join-Path $ModuleRoot 'Functions') -Include '*.ps1', '*.psm1', '*.psd1' -Recurse |
        Where-Object FullName -notmatch 'Classes' |
        ForEach-Object { @{ ScriptName = $_.Name; FullName = $_.FullName; RulesPath = $rulesPath } }

    $CommandsForTest = (Get-Command -Module $ModuleName).Name | ForEach-Object {
        $file = Get-ChildItem -Path (Join-Path $ModuleRoot 'Tests') -Filter "$_.Tests.ps1" -Recurse
        @{ CommandName = $_; TestFilePath = $file.FullName }
    }
}

Describe "All commands pass PSScriptAnalyzer rules" -Tag 'Build' {
    Context "<ScriptName>" -ForEach $ScriptsForAnalysis {
        BeforeAll {
            $script:AnalyzerResults = Invoke-ScriptAnalyzer -Path $FullName -Settings $RulesPath
        }
        It "Should not fail any rules" {
            $script:AnalyzerResults | Should -BeNullOrEmpty
        }
    }
}

Describe "Public commands have Pester tests" -Tag 'Build' {
    It "Should have a Pester test for [<CommandName>]" -ForEach $CommandsForTest {
        $TestFilePath | Should -Not -BeNullOrEmpty
    }
}
