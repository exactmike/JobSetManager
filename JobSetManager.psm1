##########################################################################################################
#core functions
##########################################################################################################
$FunctionFiles = Get-ChildItem -Recurse -File -Path $(Join-Path -Path $PSScriptRoot -ChildPath 'Functions')
foreach ($ff in $FunctionFiles) {. $ff.fullname}
$Script:JobTypes = Import-JSON -Path $(Join-Path -Path $PSScriptRoot -ChildPath 'JobTypes.json')