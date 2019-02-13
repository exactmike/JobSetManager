clear-host
Remove-Module JobSetManager
Import-Module JobSetManager -Force
$Module = Get-Module JobSetManager
$TestJobsPath = Join-Path $(Join-Path $(Join-Path $($Module.path | split-path -parent) "Tests") "Jobs") "Jobs.ps1"
$Jobs = . $TestJobsPath
#$mycredential = get-credential
$setjsmPeriodicReportSettingSplat = @{
    #SMTPCredential = $mycredential
    Units = 'seconds'
    #SMTPPort = 587
    SendEmail = $false
    MissedIntervalTrue = $true
    #From = $mycredential.Username
    #Subject = 'JSM Test Processing Update'
    #SMTPServer = 'smtp.office365.com'
    FirstTestTrue = $true
    Length = 1
    To = $($mycredential.username)
}
$reportSetting = Set-jsmPeriodicReportSetting @setjsmPeriodicReportSettingSplat
Invoke-JSMProcessingLoop -JobDefinition $Jobs -SleepSecondsBetweenJobCheck 10 -Interactive -JobFailureRetryLimit 3 -Verbose #-periodicreportsetting $reportSetting -periodicreport