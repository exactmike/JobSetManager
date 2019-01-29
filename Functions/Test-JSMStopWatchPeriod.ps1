function Test-JSMStopWatchPeriod
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [validateset('Milliseconds','Seconds','Minutes','Hours','Days')]
        [string]$Units
        ,
        [parameter(Mandatory)]
        [system.diagnostics.stopwatch]$stopwatch
        ,
        [parameter(Mandatory)]
        [int]$length
        ,
        [parameter()]
        [switch]$FirstTestTrue
        ,
        [parameter()]
        [switch]$MissedIntervalTrue
        ,
        [parameter()]
        [switch]$Reset
    )
    $currentUnits = [math]::Truncate($stopwatch.Elapsed.$('Total' + $Units))
    Write-Verbose -Message "CurrentUnits current value is $currentUnits"
    switch (Test-Path 'variable:script:LastUnits')
    {
        $true
        {
            Write-Verbose "LastUnits current value is $script:LastUnits"
        }
        $false
        {
            Write-Verbose "Creating Last Units Variable and Setting to 0"
            Set-Variable -Name LastUnits -Value 0 -Scope Script
        }
    }
    switch (Test-Path 'variable:script:FirstStopWatchPeriodTest')
    {
        $true
        {
            if ($Reset)
            {
                Set-Variable -Name FirstStopWatchPeriodTest -Value $true -Scope Script
                Write-Verbose "Setting FirstStopWatchPeriodTest to True"
            }
            else
            {
                Write-Verbose "FirstStopWatchPeriodTest  =  $script:FirstStopWatchPeriodTest"
            }
        }
        $false
        {
            Write-Verbose "Setting FirstStopWatchPeriodTest to True"
            Set-Variable -Name FirstStopWatchPeriodTest -Value $true -Scope Script
        }
    }
    $modulus = $currentUnits % $Length
    Write-Verbose "Modulus is $modulus"
    switch ($modulus)
    {
        {$modulus -eq 0 -and $script:LastUnits -ne $currentUnits}
        {
            Write-Verbose -Message "'Normal' True returned due to Modulus = $modulus and first time for currentUnits = $currentUnits"
            $true
            $script:LastUnits = $currentUnits
            break
        }
        {$script:FirstStopWatchPeriodTest -and $FirstTestTrue}
        {
            Write-Verbose -Message "'FirstTime' True returned"
            $true
            $script:LastUnits = $currentUnits
            Write-Verbose -Message "'FirstStopWatchPeriodTest' set to False"
            $script:FirstStopWatchPeriodTest = $false
            break
        }
        {($LastUnits + $length) -lt $currentUnits -and $MissedIntervalTrue}
        {
            Write-Verbose -Message "'MissedInterval' True returned due to (LastUnits + Length) >  CurrentUnits"
            $true
            $script:LastUnits = $currentUnits
            break
        }
        default
        {
            $false
        }
    }
}
