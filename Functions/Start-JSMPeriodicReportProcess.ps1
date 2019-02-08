function Start-JSMPeriodicReportProcess
{
    [CmdletBinding()]
    param
    (
        $PeriodicReportSetting,
        $JobRequired,
        $Stopwatch,
        $JobCompletion,
        $JobCurrent,
        $JobFailure
    )
    if ($null -ne $PeriodicReportSetting)
    {
        Write-Verbose -Message 'Periodic Report Settings is Not NULL'
        $TestStopWatchPeriodParams = @{
            Units = $PeriodicReportSetting.Units
            Length = $PeriodicReportSetting.Length
            Stopwatch = $stopwatch
            MissedIntervalTrue = $PeriodicReportSetting.MissedIntervalTrue
            FirstTestTrue = $PeriodicReportSetting.FirstTestTrue
        }
        [bool]$SendTheReport = Test-JSMStopWatchPeriod @TestStopWatchPeriodParams
        Write-Verbose -Message "SendtheReport is set to $SendTheReport"
    }
    if ($true -eq $SendTheReport -and $PeriodicReportSetting.SendEmail)
    {
        $body =
@"
$($script:JSMProcessingLoopStatus | ConvertTo-Html)

$(Get-JSMJobSetYUMLURL -JobSet $JobRequired -JobCompletion $JobCompletion -JobCurrent $JobCurrent -JobFailure $JobFailure -Progress)
"@
        $SendMailMessageParams = @{
            Body = $body
            Subject = $PeriodicReportSetting.Subject
            BodyAsHTML = $true
            To = $PeriodicReportSetting.To
            From = $PeriodicReportSetting.From
            SmtpServer = $PeriodicReportSetting.SmtpServer
            Port = $PeriodicReportSetting.SMTPPort
        }
        if ($null -ne $PeriodicReportSetting.SMTPCredential)
        {
            $SendMailMessageParams.Credential = $PeriodicReportSetting.SMTPCredential
        }
        Send-MailMessage @SendMailMessageParams
    }
}
