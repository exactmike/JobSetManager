function Test-JSMStopWatchPeriod
{
    <#
    .SYNOPSIS
        Tests whether a specified time interval has elapsed on a stopwatch.
    .DESCRIPTION
        Evaluates whether the given interval (defined by Units and Length) has elapsed since the
        last check. Supports optional first-call-true behavior and missed-interval detection.
        Uses script-scoped tracking variables to detect interval boundaries.
    .PARAMETER Units
        The unit of time to measure. Valid values: Milliseconds, Seconds, Minutes, Hours, Days.
    .PARAMETER Stopwatch
        The System.Diagnostics.Stopwatch instance to evaluate.
    .PARAMETER Length
        The number of units that must elapse before returning $true.
    .PARAMETER FirstTestTrue
        When specified, returns $true on the first call regardless of elapsed time.
    .PARAMETER MissedIntervalTrue
        When specified, returns $true if more than one interval was missed since the last check.
    .PARAMETER Reset
        When specified, resets the first-test state tracking variable.
    .OUTPUTS
        [bool]
    .EXAMPLE
        PS C:\> Test-JSMStopWatchPeriod -Units Minutes -Stopwatch $sw -Length 5

        Returns $true each time a 5-minute interval boundary is crossed.
    #>
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
    $InvokeUnits = "Total$Units"
    $currentUnits = [math]::Truncate($stopwatch.Elapsed.$($InvokeUnits))
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
