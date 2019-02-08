function Get-JSMJobAttempt
{
    <#
    .SYNOPSIS
        Gets Job Attempt entry(ies) from the JobAttempts Collection (A script scope variable).
    .DESCRIPTION
        Gets all Job Attempt entries (no parameters) or matching Job Attempt entries (any parameter(s)) from the JobAttempts Collection.
        JobAttempts Collection is a script scope variable used (primarily) internally by JobSetManager to track job attempts.
    .PARAMETER JobName
    Accepts one or multiple JobName string values to scope which JobAttempt(s) to get. No Wildcards supported.
    .PARAMETER Attempt
        Accepts one or multiple Attempt integer values to scope which JobAttempt(s) to get.
    .PARAMETER Active
        Accepts boolean values and defaults to $True to scope which JobAttempts to get.
        Both $True and $False can be simultaneously specified. $True will get only active (current) attempts and $False will only get inactive attempts.
    .PARAMETER JobType
        Accepts one or multiple String values from the set @(RSJob,PSJob,PSThreadJob).  Defaults to RSJob.
        This parameter is here primarily in ancticipation of future support for native PSJobs and for PSThreadJob jobs by JobSetManager.  In this version, only RSJobs are supported.
    .PARAMETER StopType
        Accepts one or multiple String values from the set @(Complete,Fail,None).  No Default value.
        Complete scopes the JobAttempts to get to those successfully completed.
        Fail scopes the JobAttempts to get to those which failed.
        None scopes the JobAttempts to get to those with no stop recorded.
    .EXAMPLE
        PS C:\> Get-JSMJobAttempt

        Gets all Job Attempt entries
    .EXAMPLE
        PS C:\> Get-JSMJobAttempt -JobName GetTheThings

        Gets all Job Attempt entries for job GetTheThings
    .EXAMPLE
        PS C:\> Get-JSMJobAttempt -JobName GetTheThings -Active $true

        Gets the active Job Attempt entry for job GetTheThings
    .OUTPUTS
        [pscustomobject]
    .NOTES
        Website: https://github.com/exactmike/JobSetManager
        Copyright: (c) 2019 by Mike Campbell, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT
    #>
    [cmdletbinding(DefaultParameterSetName = 'All')]
    param(
        [parameter(ParameterSetName = 'Specific')]
        [string[]]$JobName
        ,
        [parameter(ParameterSetName = 'Specific')]
        [int[]]$Attempt
        ,
        [parameter(ParameterSetName = 'Specific')]
        [ValidateCount(1,2)]
        [bool[]]$Active = $true
        ,
        [parameter(ParameterSetName = 'Specific')]
        [ValidateSet('RSJob','PSJob','PSThreadJob')]
        [string[]]$JobType = 'RSJob'
        ,
        [parameter(ParameterSetName = 'Specific')]
        [ValidateSet('Complete','Fail','None')]
        [object[]]$StopType
    )
    Initialize-TrackingVariable
    switch ($PSCmdlet.ParameterSetName)
    {
        'All'
        {$script:JobAttempts}
        'Specific'
        {
            foreach ($k in $MyInvocation.Mycommand.Parameters.keys)
            {
                $CommonParameters = Get-CommonParameter
                if ($k -notin $CommonParameters -and $k -notin $PSBoundParameters.Keys)
                {
                    switch ($k)
                    {
                        'Active'
                        {
                            Set-Variable -Name $k -Value @($true,$false)
                        }
                        "JobType"
                        {
                            Set-Variable -Name $k -Value @('RSJob','PSJob')
                        }
                        "StopType"
                        {
                            Set-Variable -Name $k -Value @('Complete','Fail','None')
                        }
                        Default
                        {
                            Set-Variable -Name $k -Value $null -Scope Local
                        }
                    }
                }
            }
            $script:JobAttempts.where({
                ($null -eq $JobName -or $_.JobName -in $JobName) -and
                ($null -eq $Attempt -or $_.Attempt -in $Attempt) -and
                ($null -eq $Active -or $_.Active -in $Active) -and
                ($null -eq $JobType -or $_.JobType -in $JobType) -and
                ($null -eq $StopType -or $_.StopType -in $StopType)
            })
        }
    }

}