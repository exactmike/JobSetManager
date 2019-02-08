function Start-JSMPeriodicReportProcess
{
    [CmdletBinding()]
    param
    (
        $PeriodicReportSetting,
        $JobRequired,
        $stopwatch,
        $JobCompletion,
        $JobCurrent,
        $JobFailure
    )
    if ($null -ne $PeriodicReportSettings)
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

$(Get-JSMJobSetYUMLURL -JobSet $JobRquired -JobCompletion $JobCompletion -JobCurrent $JobCurrent -JobFailure $JobFailure -Progress)
"@
        $SendMailMessageParams = @{
            Body = $body
            Subject = $PeriodicReportSetting.Subject
            BodyAsHTML = $true
            To = $PeriodicReportSetting.Recipient
            From = $PeriodicReportSetting.Sender
            SmtpServer = $PeriodicReportSetting.SmtpServer
        }
        if ($PeriodicReportSetting.attachlog)
        {
            $SendMailMessageParams.attachments = $logpath
        }
        Send-MailMessage @SendMailMessageParams
    }
}
