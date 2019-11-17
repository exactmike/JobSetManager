##########################################################################################################
#core functions
##########################################################################################################
$AllFunctionFiles =
Get-ChildItem -Recurse -File -Filter *.ps1 -Path $(Join-Path -Path $PSScriptRoot -ChildPath 'Functions')
$AllFunctionFiles.foreach( { . $_.fullname })
$Script:JobTypes = @{ }
(Import-JSON -Path $(Join-Path -Path $PSScriptRoot -ChildPath 'JobTypes.json') |
    Select-Object -ExpandProperty JobTypes).foreach(
    { $Script:JobTypes.$($_.Name) = $_ }
)