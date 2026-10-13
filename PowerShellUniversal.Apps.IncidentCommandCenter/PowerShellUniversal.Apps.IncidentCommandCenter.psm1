#Requires -Version 7.5.4
. (Join-Path $PSScriptRoot 'private/Icc.Acknowledgment.State.ps1')
. (Join-Path $PSScriptRoot 'private/Exercise.ps1')
. (Join-Path $PSScriptRoot 'private/Presentation.ps1')
. (Join-Path $PSScriptRoot 'private/Mcp.ps1')

function New-UDIncidentCommandCenterApp {
    $Cache:IccShowcaseModuleRoot = $PSScriptRoot
    $Cache:IccShowcaseCss = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'dashboard/incident-command-center.css'))
    & (Join-Path $PSScriptRoot 'dashboard/IncidentCommandCenter.ps1')
}

Export-ModuleMember -Function New-UDIncidentCommandCenterApp,New-IccDemoExercise,Get-IccDemoExercise,Invoke-IccDemoAction,Get-IccDemoHandoff,Get-IccDemoView,Invoke-IccDemoToolOperation
