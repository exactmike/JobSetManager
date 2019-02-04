function Start-JSMPeriodicReportProcess
{
    [CmdletBinding()]
    param
    (
        $PeriodicReportSettings,
        $RequiredJob,
        $stopwatch,
        $CompletedJob,
        $CurrentJob,
        $FailedJob
    )
    if ($null -ne $PeriodicReportSettings)
    {
        Write-Verbose -Message 'Periodic Report Settings is Not NULL'
        $TestStopWatchPeriodParams = @{
            Units = $PeriodicReportSettings.Units
            Length = $PeriodicReportSettings.Length
            Stopwatch = $stopwatch
            MissedIntervalTrue = $PeriodicReportSettings.MissedIntervalTrue
            FirstTestTrue = $PeriodicReportSettings.FirstTestTrue
        }
        [bool]$SendTheReport = Test-JSMStopWatchPeriod @TestStopWatchPeriodParams
        Write-Verbose -Message "SendtheReport is set to $SendTheReport"
    }
    if ($true -eq $SendTheReport -and $PeriodicReportSettings.SendEmail)
    {
        $body =
@"
$($script:JSMProcessingLoopStatus | ConvertTo-Html)

$(Get-JSMJobSetYUMLURL -JobSet $RequiredJobs -CompletedJobs $CompletedJobs -CurrentJobs $CurrentJobs -FailedJobs $FailedJobs -Progress)
"@
        $SendMailMessageParams = @{
            Body = $body
            Subject = $PeriodicReportSettings.Subject
            BodyAsHTML = $true
            To = $PeriodicReportSettings.Recipient
            From = $PeriodicReportSettings.Sender
            SmtpServer = $PeriodicReportSettings.SmtpServer
        }
        if ($PeriodicReportSettings.attachlog)
        {
            $SendMailMessageParams.attachments = $logpath
        }
        Send-MailMessage @SendMailMessageParams
    }
}
