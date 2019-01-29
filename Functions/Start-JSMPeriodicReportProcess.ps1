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
    if ($SendTheReport)
    {
        if ($PeriodicReportSettings.SendEmail -eq $true -or $PeriodicReportSettings.WriteLog -eq $true)
        {
            $PeriodicReportJobStatus = @(
                foreach ($rj in $RequiredJob)
                {
                    switch ($CompletedJob.ContainsKey($rj.name))
                    {
                        $true
                        {
                            [PSCustomObject]@{
                                Name = $rj.name
                                Status = 'Completed'
                                StartTime = $rj.StartTime
                                EndTime = $rj.EndTime
                                ElapsedMinutes = [math]::round($(New-TimeSpan -Start $rj.StartTime -End $rj.EndTime).TotalMinutes,1)
                            }
                        }
                        $false
                        {
                            switch ($CurrentJob.ContainsKey($rj.name))
                            {
                                $true
                                {
                                    [PSCustomObject]@{
                                        Name = $rj.name
                                        Status = 'Processing'
                                        StartTime = $rj.StartTime
                                        EndTime = $null
                                        ElapsedMinutes = [math]::Round($(New-TimeSpan -Start $rj.StartTime -End (Get-Date)).TotalMinutes,1)
                                    }
                                }
                                $false
                                {
                                    [PSCustomObject]@{
                                        Name = $rj.name
                                        Status = 'Pending'
                                        StartTime = $null
                                        EndTime = $null
                                        ElapsedMinutes = $null
                                    }
                                }
                            }
                        }
                    }
                    switch ($FailedJob.ContainsKey($rj.name))
                    {
                        $true
                        {
                            [PSCustomObject]@{
                                Name = $rj.name
                                Status = "Has $($FailedJob.$($rj.Name).FailureCount) Failed Attempts"
                                StartTime = $null
                                EndTime = $null
                                ElapsedMinutes = $null
                            }
                        }
                    }
                }
            )
            $PeriodicReportJobStatus = $PeriodicReportJobStatus | Sort-Object StartTime,EndTime
        }
        if ($PeriodicReportSettings.SendEmail)
        {

            #$($script:JSMProcessingLoopStatus | ConvertTo-Html)
$body =
@"
$($PeriodicReportJobStatus | ConvertTo-Html)

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
}
