$CommandName = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")

Describe "$CommandName Unit Tests" -Tag 'UnitTests' {
    Context "Validate parameters" {
        It "Should have the expected parameters" {
            [object[]]$params = (Get-ChildItem "function:\$CommandName").Parameters.Keys
            $knownParameters = @('SendEmail', 'To', 'From', 'Subject', 'SMTPServer', 'SMTPPort',
                'SMTPUseSSL', 'SMTPCredential', 'Units', 'Length', 'MissedIntervalTrue',
                'FirstTestTrue', 'LogFilePath')
            foreach ($kp in $knownParameters) { $kp | Should -BeIn $params }
        }
    }
}

Describe "$CommandName Integration Tests" -Tag 'IntegrationTests' {
    BeforeAll {
        & (Get-Module JobSetManager) { $Script:JSMPeriodicReportSetting = $null }
    }
    AfterAll {
        & (Get-Module JobSetManager) { $Script:JSMPeriodicReportSetting = $null }
    }

    Context "Creates default settings on first call" {
        BeforeAll {
            $script:Setting = Set-JSMPeriodicReportSetting -Units Minutes -Length 30
        }
        It "outputs a pscustomobject" {
            $script:Setting | Should -BeOfType [pscustomobject]
        }
        It "defaults SendEmail to false" {
            $script:Setting.SendEmail | Should -Be $false
        }
        It "defaults SMTPServer to smtp.office365.com" {
            $script:Setting.SMTPServer | Should -Be 'smtp.office365.com'
        }
        It "defaults SMTPPort to 25" {
            $script:Setting.SMTPPort | Should -Be 25
        }
        It "defaults SMTPUseSSL to true" {
            $script:Setting.SMTPUseSSL | Should -Be $true
        }
        It "sets Units to the specified value" {
            $script:Setting.Units | Should -Be 'Minutes'
        }
        It "sets Length to the specified value" {
            $script:Setting.Length | Should -Be 30
        }
        It "defaults MissedIntervalTrue to true" {
            $script:Setting.MissedIntervalTrue | Should -Be $true
        }
        It "defaults FirstTestTrue to true" {
            $script:Setting.FirstTestTrue | Should -Be $true
        }
        It "defaults LogFilePath to null" {
            $script:Setting.LogFilePath | Should -BeNullOrEmpty
        }
    }

    Context "Only updates explicitly provided parameters" {
        BeforeAll {
            $script:Setting2 = Set-JSMPeriodicReportSetting -SendEmail $true
        }
        It "updates SendEmail" {
            $script:Setting2.SendEmail | Should -Be $true
        }
        It "preserves previously set Units" {
            $script:Setting2.Units | Should -Be 'Minutes'
        }
        It "preserves previously set Length" {
            $script:Setting2.Length | Should -Be 30
        }
        It "preserves default SMTPServer" {
            $script:Setting2.SMTPServer | Should -Be 'smtp.office365.com'
        }
    }

    Context "Can update email delivery settings" {
        BeforeAll {
            $script:Setting3 = Set-JSMPeriodicReportSetting -To 'admin@corp.com' -From 'noreply@corp.com' -Subject 'JSM Report'
        }
        It "sets To address" {
            $script:Setting3.To | Should -Be 'admin@corp.com'
        }
        It "sets From address" {
            $script:Setting3.From | Should -Be 'noreply@corp.com'
        }
        It "sets Subject" {
            $script:Setting3.Subject | Should -Be 'JSM Report'
        }
    }
}
