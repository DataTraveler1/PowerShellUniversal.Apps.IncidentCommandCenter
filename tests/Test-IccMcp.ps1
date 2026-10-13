#Requires -Version 7.5.4
param([string]$OutputDirectory = (Join-Path $PSScriptRoot ('../output/mcp-test-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference = 'Stop'
$previousRoot = $env:ICC_DEMO_DATA_ROOT
$env:ICC_DEMO_DATA_ROOT = [IO.Path]::GetFullPath($OutputDirectory)
$checks = 0
function Confirm-Icc($Condition, $Message) { if (-not $Condition) { throw $Message }; $script:checks++ }
try {
    Import-Module (Join-Path $PSScriptRoot '../PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1') -Force
    $first = New-IccDemoExercise
    $inspect = Invoke-IccDemoToolOperation -Action Inspect
    Confirm-Icc ($inspect.exerciseId -eq $first.ExerciseId -and $inspect.status -eq 'Open') 'Inspect must target the active rehearsal.'
    $refused = $false
    try { Invoke-IccDemoToolOperation -Action Acknowledge | Out-Null } catch { $refused = $true }
    Confirm-Icc $refused 'Acknowledgment must require an exercise ID.'
    $ack = Invoke-IccDemoToolOperation -Action Acknowledge -ExerciseId $inspect.exerciseId
    Confirm-Icc ($ack.disposition -eq 'Acknowledged' -and $ack.transitionCount -eq 1) 'Acknowledgment must make one transition.'
    $verified = Invoke-IccDemoToolOperation -Action Inspect -ExerciseId $inspect.exerciseId
    Confirm-Icc ($verified.stateSha256 -eq $ack.stateSha256 -and $verified.explicitStateReads -eq 1) 'Inspect must verify saved state.'
    $repeat = Invoke-IccDemoToolOperation -Action Acknowledge -ExerciseId $inspect.exerciseId
    Confirm-Icc ($repeat.disposition -eq 'AlreadyAcknowledged' -and $repeat.acknowledgedAtUtc -eq $ack.acknowledgedAtUtc -and $repeat.stateSha256 -eq $ack.stateSha256) 'Repeat must preserve the response.'
    $handoff = Invoke-IccDemoToolOperation -Action Handoff -ExerciseId $inspect.exerciseId
    Confirm-Icc ($handoff.handoff.Contains('ACME INC.') -and $handoff.handoff.Contains('Safe repeat acknowledgments: 1')) 'Handoff must reflect actual events.'
    $next = New-IccDemoExercise
    $refused = $false
    try { Invoke-IccDemoToolOperation -Action Acknowledge -ExerciseId $inspect.exerciseId | Out-Null } catch { $refused = $true }
    Confirm-Icc $refused 'A stale rehearsal must be rejected.'
    Confirm-Icc ((Get-IccDemoExercise -ExerciseId $next.ExerciseId).State.incidentStatus -eq 'Open') 'Stale requests must not acknowledge the new rehearsal.'
    [pscustomobject]@{outcome='PASS';checks=$checks;psuRequests=0} | ConvertTo-Json
} finally { $env:ICC_DEMO_DATA_ROOT = $previousRoot }
