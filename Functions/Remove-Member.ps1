    Function Remove-Member
    {
    <#
    .SYNOPSIS
        Removes a named member from one or more PSObjects.
    .DESCRIPTION
        Iterates each object in the pipeline and removes the specified member
        (NoteProperty, ScriptProperty, etc.) using the PSObject Members.Remove() method.
    .PARAMETER Object
        One or more PSObjects from which to remove the member.
    .PARAMETER Member
        The name of the member to remove.
    .EXAMPLE
        PS C:\> $obj | Remove-Member -Member 'TempProp'

        Removes the 'TempProp' member from $obj.
    #>
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory, ValueFromPipeline)]
        [psobject[]]$Object
        ,
        [parameter(Mandatory)]
        [string]$Member
    )
    begin {}
    process
    {
        foreach ($o in $Object)
        {
            $o.psobject.Members.Remove($Member)
        }
    }

    }

