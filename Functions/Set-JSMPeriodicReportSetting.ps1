function Set-JSMPeriodicReportSetting
{
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
