function Get-JSMJobCurrent
{
    <#
        .SYNOPSIS
            Gets the Current JSM Jobs that have 'Active' Attempts.
        .DESCRIPTION
            Gets the Current JSM Jobs that have 'Active' Attempts using the function Get-JSMJobAttempt -Active $true.
        .EXAMPLE
            $null = Start-JSMJob -Job @{Name = 'Sleep';Message = 'Sleeps 10 seconds';StartJobParams = @{ScriptBlock = {Start-Sleep -Seconds 10}}}
            Get-JSMJobCurrent

            Gets the current Job attempts which should include the job Sleep

        .OUTPUTS
            [pscustomobject]
    #>
    [cmdletbinding()]
    param()
    $CurrentJSMJobs = @(Get-JSMJobAttempt -Active $true)
    $CurrentJSMJobs
}