$ModuleName = 'JobSetManager'

Describe "Public commands have comment-based or external help" -Tags 'Build' {
    BeforeAll {
        $functions = Get-Command -Module $ModuleName
        $help = foreach ($function in $functions) {
            Get-Help -Name $function.Name
        }
    }

    It "Should have a Description or Synopsis for [<Name>]" -ForEach @(
        (Get-Command -Module $ModuleName) | ForEach-Object { @{ Name = $_.Name } }
    ) {
        $node = Get-Help -Name $Name
        ($node.Description | Out-String) + ($node.Synopsis | Out-String) | Should -Not -BeNullOrEmpty
    }

    It "Should have an Example for [<Name>]" -ForEach @(
        (Get-Command -Module $ModuleName) | ForEach-Object { @{ Name = $_.Name } }
    ) {
        $node = Get-Help -Name $Name
        $node.Examples | Should -Not -BeNullOrEmpty
        $node.Examples | Out-String | Should -Match $Name
    }

    It "Parameter [<ParameterName>] of [<CommandName>] should have a description" -ForEach @(
        (Get-Command -Module $ModuleName) | ForEach-Object {
            $cmdName = $_.Name
            $node = Get-Help -Name $cmdName
            foreach ($parameter in $node.Parameters.Parameter)
            {
                if ($parameter.Name -notmatch 'WhatIf|Confirm')
                {
                    @{ CommandName = $cmdName; ParameterName = $parameter.Name; Parameter = $parameter }
                }
            }
        }
    ) {
        $Parameter.Description.Text | Should -Not -BeNullOrEmpty
    }
}
