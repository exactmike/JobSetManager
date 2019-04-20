function Set-JSMPeriodicReportSetting
{
    [cmdletbinding()]
    param
    (
        [bool]$SendEmail = $false
        ,
        $To
        ,
        $From
        ,
        $Subject
        ,
        [parameter()]
        [string]$SMTPServer = 'smtp.office365.com'
        ,
        [parameter()]
        [ValidateSet(25,587)]
        [int]$SMTPPort = 25
        ,
        #Specify whether to use SSL/TLS when sending the SMTP message.  Default is $True.
        [Parameter()]
        [bool]$SMTPUseSSL = $true
        ,
        [parameter()]
        [pscredential]$SMTPCredential
        ,
        [parameter()]
        [validateset('Milliseconds','Seconds','Minutes','Hours','Days')]
        $Units = 'Minutes'
        ,
        [parameter()]
        $Length
        ,
        [bool]$MissedIntervalTrue = $true
        ,
        [bool]$FirstTestTrue = $true
        ,
        [parameter()]
        [ValidateScript({Test-Path -Path $(Split-Path -Path $_ -Parent)})]
        $LogFilePath
    )
    $Script:JSMPeriodicReportSetting = [PSCustomObject]@{
        SendEmail = $SendEmail
        WriteLog = $WriteLog
        SMTPServer = $SMTPServer
        SMTPPort = $SMTPPort
        SMTPUseSSL = $SMTPUseSSL
        SMTPCredential = $SMTPCredential
        To = $To
        From = $From
        Subject = $Subject
        Units = $Units
        Length = $Length
        MissedIntervalTrue = $MissedIntervalTrue
        FirstTestTrue = $FirstTestTrue
        LogFilePath = $LogFilePath
    }
    $Script:JSMPeriodicReportSetting
}
