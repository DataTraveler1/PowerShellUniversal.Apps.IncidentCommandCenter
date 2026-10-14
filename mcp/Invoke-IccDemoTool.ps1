#Requires -Version 7.5.4
<#
.SYNOPSIS
Inspect, acknowledge, and hand off the current Acme Inc. incident rehearsal.
.DESCRIPTION
Use Inspect to obtain current facts and the full exercise ID. Inspect adds a
read event. Acknowledge changes demo state once and preserves the first response
on repeats. Handoff returns saved facts for a summary. Never claims remediation.
.PARAMETER Action
Inspect, Acknowledge, or Handoff. Start with Inspect.
.PARAMETER ExerciseId
Exact full exercise ID from Inspect. Required for Acknowledge and Handoff.
#>
param(
    [Parameter(Mandatory)][ValidateSet('Inspect','Acknowledge','Handoff')][string]$Action,
    [string]$ExerciseId = ''
)
$ErrorActionPreference = 'Stop'
$manifest = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/Showcases/IncidentCommandCenter/0.1.2/PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1'
Import-Module $manifest -Force
Invoke-IccDemoToolOperation -Action $Action -ExerciseId $ExerciseId | ConvertTo-Json -Depth 6 -Compress
