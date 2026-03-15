    Function Add-RequiredMember
    {
        
    <#
    .SYNOPSIS
        Ensures that specified members exist on each input object, adding null-valued NoteProperties for any that are missing.
    .DESCRIPTION
        Iterates each object in InputObject. For each name in RequiredMember that is not null or empty,
        adds a null-valued NoteProperty if the member does not already exist on the object.
    .PARAMETER RequiredMember
        An array of member names that must exist on each input object. Null and empty strings are skipped.
    .PARAMETER InputObject
        One or more PSObjects to check and augment with required members.
    .EXAMPLE
        PS C:\> $obj | Add-RequiredMember -RequiredMember 'Status','Result'

        Adds 'Status' and 'Result' as null NoteProperties on $obj if they are not already present.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$RequiredMember
        ,
        [Parameter(Mandatory, ValueFromPipeline, Position = 2)]
        [psobject[]]$InputObject
    )
    Process
    {
        foreach ($io in $InputObject)
        {
            foreach ($rm in $RequiredMember)
            {
                if ($null -ne $rm -and -not [string]::IsNullOrEmpty($rm))
                {
                    if (-not (Test-Member -InputObject $io -Name $rm))
                    {
                        Add-Member -InputObject $io -MemberType NoteProperty -Name $rm -Value $null
                    }
                }
            }
        }
    }

    }

