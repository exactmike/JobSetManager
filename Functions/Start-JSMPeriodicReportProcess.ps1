function Start-JSMPeriodicReportProcess
{
    <#
    .SYNOPSIS
        Executes the periodic reporting step within the JSM processing loop.
    .DESCRIPTION
        When Interactive is $true, writes verbose status output listing pending, running,
        completed, and failed jobs each iteration. When PeriodicReportSetting is configured,
        evaluates the report interval and optionally writes a CSV log and sends an email
        report with the job set progress diagram as an attachment.
    .PARAMETER PeriodicReportSetting
        The settings object from Set-JSMPeriodicReportSetting. Pass $null to skip email/log steps.
    .PARAMETER JobRequired
        The array of required job definitions.
    .PARAMETER Stopwatch
        The module stopwatch instance used to evaluate the report interval.
    .PARAMETER JobCompletion
        Hashtable of completed jobs.
    .PARAMETER StartJobSuccess
        Collection of jobs successfully started in the current iteration.
    .PARAMETER JobCurrent
        Hashtable of currently running jobs.
    .PARAMETER JobPending
        Hashtable of pending jobs.
    .PARAMETER JobFailure
        Hashtable of failed jobs.
    .PARAMETER Interactive
        When $true, outputs verbose status to the console each iteration.
    .PARAMETER FatalFailure
        When $true, indicates a fatal failure has occurred and adds a notice to verbose output.
    .EXAMPLE
        PS C:\> Start-JSMPeriodicReportProcess -PeriodicReportSetting $setting -JobRequired $jobs -Stopwatch $sw -JobCompletion $completions -StartJobSuccess $started -JobCurrent $current -JobPending $pending -JobFailure $failures -Interactive $true -FatalFailure $false

        Prints interactive status and evaluates whether to send a periodic email report.
    #>
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
        # Note: Send-MailMessage is deprecated in PS 7.x and emits a deprecation warning.
        # It remains functional on all platforms but may be removed in a future PS release.
        Send-MailMessage @SendMailMessageParams
    }
}
