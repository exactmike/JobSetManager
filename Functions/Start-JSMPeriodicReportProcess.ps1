function Start-JSMPeriodicReportProcess
{
    [CmdletBinding()]
    param
    (
        [parameter()]
        [AllowNull()]
        $PeriodicReportSetting,
        $JobRequired,
        $Stopwatch,
        $JobCompletion,
        $StartJobSuccess,
        $JobCurrent,
        $JobPending,
        $JobFailure,
        $Interactive,
        $FatalFailure
    )
    if ($true -eq $Interactive)
    {
        $originalVerbosePreference = $VerbosePreference
        $VerbosePreference = 'Continue'
        Write-Verbose -Message "=========================================================================="
        Write-Verbose -Message "$(Get-Date)"
        Write-Verbose -Message "=========================================================================="
        Write-Verbose -Message "Pending Jobs: $(($JobPending.Keys | sort-object) -join ' | | ')"
        Write-Verbose -Message "=========================================================================="
        Write-Verbose -Message "Started Jobs: $(($StartJobSuccess.Name | sort-object) -join ' | | ')"
        Write-Verbose -Message "=========================================================================="
        Write-Verbose -Message "Currently Running Jobs: $(($JobCurrent.Keys | sort-object) -join ' | | ')"
        Write-Verbose -Message "=========================================================================="
        Write-Verbose -Message "Completed Jobs: $(($JobCompletion.Keys | sort-object) -join ' | | ' )"
        Write-Verbose -Message "=========================================================================="
        if ($JobFailure.Keys.Count -ge 1)
        {
            Write-Verbose -Message "Jobs With Failed Attempts: $(($Script:JobFailure.Keys | sort-object) -join ' | | ' )"
            Write-Verbose -Message "=========================================================================="
        }
        if ($true -eq $FatalFailure)
        {
            Write-Verbose -Message "A Fatal Job Failure Has Occurred"
            Write-Verbose -Message "=========================================================================="
        }
        $VerbosePreference = $originalVerbosePreference
    }
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
        if ($null -ne $PeriodicReportSetting.LogFilePath)
        {
            Write-Verbose -Message "Logging JSM Processing Status to $($PeriodicReportSetting.LogFilePath)"
            $script:JSMProcessingLoopStatus | Export-Csv -Path $PeriodicReportSetting.LogFilePath -NoTypeInformation -Force -UseCulture
        }
    }
    if ($true -eq $SendTheReport -and $PeriodicReportSetting.SendEmail)
    {
        $body =
@"
$($script:JSMProcessingLoopStatus | ConvertTo-Html)
"@
        $getJSMJobSetDiagramSplat = @{
            JobFailure = $JobFailure
            JobSet = $JobRequired
            JobCompletion = $JobCompletion
            JobCurrent = $JobCurrent
            Progress = $true
        }
        $attachment = Get-JSMJobSetDiagram @getJSMJobSetDiagramSplat
        $SendMailMessageParams = @{
            Body = $body
            Subject = $PeriodicReportSetting.Subject
            BodyAsHTML = $true
            To = $PeriodicReportSetting.To
            From = $PeriodicReportSetting.From
            SmtpServer = $PeriodicReportSetting.SmtpServer
            Port = $PeriodicReportSetting.SMTPPort
            Attachments = $attachment.fullname
        }
        if ($null -ne $PeriodicReportSetting.SMTPCredential)
        {
            $SendMailMessageParams.Credential = $PeriodicReportSetting.SMTPCredential
        }
        if ($true -eq $PeriodicReportSetting.SMTPUseSSL)
        {
            $SendMailMessageParams.UseSSL = $true
        }
        Send-MailMessage @SendMailMessageParams
    }
}
