function Set-JSMPeriodicReportSetting
{
    <#
    .SYNOPSIS
        Configures periodic report settings for the JSM processing loop.
    .DESCRIPTION
        Creates or updates the script-scoped JSMPeriodicReportSetting object. Only parameters
        explicitly provided are updated; all other settings retain their current values.
        Creates default settings on the first call.
    .PARAMETER SendEmail
        Whether to send an email report when the interval elapses.
    .PARAMETER To
        The email recipient address(es).
    .PARAMETER From
        The sender email address.
    .PARAMETER Subject
        The email subject line.
    .PARAMETER SMTPServer
        The SMTP server hostname. Default: smtp.office365.com.
    .PARAMETER SMTPPort
        The SMTP port. Valid values: 25 or 587.
    .PARAMETER SMTPUseSSL
        Whether to use SSL/TLS when connecting to the SMTP server. Default: $true.
    .PARAMETER SMTPCredential
        PSCredential for SMTP authentication.
    .PARAMETER Units
        The time unit for the report interval. Valid: Milliseconds, Seconds, Minutes, Hours, Days.
    .PARAMETER Length
        The number of units between each report.
    .PARAMETER MissedIntervalTrue
        Whether to send a report if an interval was missed since the last check. Default: $true.
    .PARAMETER FirstTestTrue
        Whether to send a report immediately on the first interval check. Default: $true.
    .PARAMETER LogFilePath
        Path to a CSV log file for JSMProcessingLoopStatus. Parent directory must exist.
    .OUTPUTS
        [pscustomobject]
    .EXAMPLE
        PS C:\> Set-JSMPeriodicReportSetting -SendEmail $true -To 'admin@corp.com' -Units Minutes -Length 30

        Configures the module to send an email report every 30 minutes.
    #>
    [cmdletbinding()]
    param
    (
        [bool]$SendEmail
        ,
        $To
        ,
        $From
        ,
        $Subject
        ,
        [parameter()]
        [string]$SMTPServer
        ,
        [parameter()]
        [ValidateSet(25,587)]
        [int]$SMTPPort
        ,
        #Specify whether to use SSL/TLS when sending the SMTP message.  Default is $True.
        [Parameter()]
        [bool]$SMTPUseSSL
        ,
        [parameter()]
        [pscredential]$SMTPCredential
        ,
        [parameter()]
        [validateset('Milliseconds','Seconds','Minutes','Hours','Days')]
        $Units
        ,
        [parameter()]
        $Length
        ,
        [bool]$MissedIntervalTrue
        ,
        [bool]$FirstTestTrue
        ,
        [parameter()]
        [ValidateScript({Test-Path -Path $(Split-Path -Path $_ -Parent)})]
        $LogFilePath
    )
    # Initialize with defaults if no existing settings object
    if ($null -eq $Script:JSMPeriodicReportSetting)
    {
        $Script:JSMPeriodicReportSetting = [PSCustomObject]@{
            SendEmail        = $false
            SMTPServer       = 'smtp.office365.com'
            SMTPPort         = 25
            SMTPUseSSL       = $true
            SMTPCredential   = $null
            To               = $null
            From             = $null
            Subject          = $null
            Units            = 'Minutes'
            Length           = $null
            MissedIntervalTrue = $true
            FirstTestTrue    = $true
            LogFilePath      = $null
        }
    }
    # Only update properties that were explicitly specified
    foreach ($key in $PSBoundParameters.Keys)
    {
        $Script:JSMPeriodicReportSetting.$key = $PSBoundParameters[$key]
    }
    $Script:JSMPeriodicReportSetting
}
