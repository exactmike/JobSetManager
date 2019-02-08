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
    )
    $Script:JSMPeriodicReportSetting = [PSCustomObject]@{
        SendEmail = $SendEmail
        WriteLog = $WriteLog
        SMTPServer = $SMTPServer
        SMTPPort = $SMTPPort
        SMTPCredential = $SMTPCredential
        To = $To
        From = $From
        Subject = $Subject
        Units = $Units
        Length = $Length
        MissedIntervalTrue = $MissedIntervalTrue
        FirstTestTrue = $FirstTestTrue
    }
    $Script:JSMPeriodicReportSetting
}
