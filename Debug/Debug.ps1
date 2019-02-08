Remove-Module JobSetManager
Import-Module JobSetManager -Force
$Module = Get-Module JobSetManager
$TestJobsPath = Join-Path $(Join-Path $(Join-Path $($Module.path | split-path -parent) "Tests") "Jobs") "Jobs.ps1"
$Jobs = . $TestJobsPath
$mycredential = get-credential
$reportSetting = Set-jsmPeriodicReportSetting -SendEmail $true -to $($mycredential.username) -subject 'JSM Test Processing Update' -smtpserver smtp.office365.com -smtpport 587 -smtpCredential $mycredential -units seconds -FirstTestTrue $true -MissedIntervalTrue $true -from $mycredential.Username -length 1
Invoke-JSMProcessingLoop -JobDefinition $Jobs -SleepSecondsBetweenJobCheck 5 -Interactive -JobFailureRetryLimit 3 -periodicreportsetting $reportSetting -periodicreport