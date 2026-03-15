$ModuleName = 'JobSetManager'
$SourceRoot = 'Functions'
$ModuleRoot = Split-Path $(Split-Path -Path $PSCommandPath -Parent) -Parent

$rules = "$ModuleRoot\ScriptAnalyzerSettings.psd1"
$scripts = Get-ChildItem -Path $SourceRoot -Include '*.ps1', '*.psm1', '*.psd1' -Recurse |
    Where-Object FullName -notmatch 'Classes'

Describe "All commands pass PSScriptAnalyzer rules" -Tag 'Build' {
    foreach ($script in $scripts)
    {
        Context $script.FullName {
            $results = Invoke-ScriptAnalyzer -Path $script.FullName -Settings $rules
            if ($results)
            {
                foreach ($rule in $results)
                {
                    It $rule.RuleName {
                        $message = "{0} Line {1}: {2}" -f $rule.Severity, $rule.Line, $rule.Message
                        $message | Should -Be ""
                    }
                }
            }
            else
            {
                It "Should not fail any rules" {
                    $results | Should -BeNullOrEmpty
                }
            }
        }
    }
}

Describe "Public commands have Pester tests" -Tag 'Build' {
    $commands = Get-Command -Module $ModuleName

    foreach ($command in $commands.Name)
    {
        $file = Get-ChildItem -Path "$ModuleRoot\Tests" -Include "$command.Tests.ps1" -Recurse
        It "Should have a Pester test for [$command]" {
            $file.FullName | Should -Not -BeNullOrEmpty
        }
    }
}
