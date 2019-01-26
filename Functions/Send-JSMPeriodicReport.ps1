function Send-JSMPeriodicReport
{
    [CmdletBinding()]
    param
    (
        $PeriodicReportSettings,
        $RequiredJobs,
        $stopwatch,
        $CompletedJobs,
        $CurrentJobs,
        $FailedJobs
    )
    if ($PeriodicReportSettings -ne $null)
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
            $currentRSJobs = @{}
            $rsjobs = @(Get-RSJob)
            foreach ($rsj in $rsjobs)
            {
                $currentRSJobs.$($rsj.name) = $true
            }
            $PeriodicReportJobStatus = @(
                foreach ($rj in $RequiredJobs)
                {
                    switch ($CompletedJobs.ContainsKey($rj.name))
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
                            switch ($currentRSJobs.ContainsKey($rj.name))
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
                            Write-Verbose -message "Current Jobs: $($currentRSJobs.keys -join ',')"
                        }
                    }
                }
            )
            $PeriodicReportJobStatus = $PeriodicReportJobStatus | Sort-Object StartTime,EndTime
        }
        if ($PeriodicReportSettings.SendEmail)
        {
            $body = "$($PeriodicReportJobStatus | ConvertTo-Html)"
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
