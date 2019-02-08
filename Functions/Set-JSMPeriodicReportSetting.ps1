function Set-JSMPeriodicReportSetting
{
    [cmdletbinding()]
    param
    (
        [bool]$SendEmail = $false
        ,
        $Recipient
        ,
        $Sender
        ,
        $subject
        ,
        [bool]$attachLog
        ,
        [parameter()]
        [string]$SMTPServer = 'smtp.office365.com'
        ,
        [parameter()]
        [ValidateSet(25,587)]
        [int]$SMTPPort = 25
        ,
        [parameter()]
        [pscredential]$SMTPCredential
        ,
        [bool]$WriteLog = $true
        ,
        [parameter()]
        [validateset('Milliseconds','Seconds','Minutes','Hours','Days')]
        $units = 'Minutes'
        ,
        [parameter()]
        $length
        ,
        [bool]$MissedIntervalTrue = $true
        ,
        [bool]$FirstTestTrue = $true
    )
    $Script:JSMPeriodicReportSetting = [PSCustomObject]@{
        SendEmail = $SendEmail
        WriteLog = $WriteLog
        SMTPServer = $SMTPServer
        SMTPPort = $SMTPPort
        SMTPCredential = $SMTPCredential
        Recipient = $Recipient
        Sender = $Sender
        Subject = $subject
        attachlog = $attachLog
        Units = $units
        Length = $length
        MissedIntervalTrue = $MissedIntervalTrue
        FirstTestTrue = $FirstTestTrue
    }
    $Script:JSMPeriodicReportSetting
}
