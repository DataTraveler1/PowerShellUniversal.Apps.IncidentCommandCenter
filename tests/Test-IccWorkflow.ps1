#Requires -Version 7.5.4
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot ('../output/workflow-test-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference = 'Stop'
$previousRoot = $env:ICC_DEMO_DATA_ROOT
$env:ICC_DEMO_DATA_ROOT = [IO.Path]::GetFullPath((Join-Path $OutputDirectory 'data'))
$checks = 0
function Confirm-IccWorkflow($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Get-IccFixtureInventory {
    @(Get-ChildItem -LiteralPath $env:ICC_DEMO_DATA_ROOT -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($env:ICC_DEMO_DATA_ROOT.Length) + '|' + $_.Length + '|' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash + '|' + $_.LastWriteTimeUtc.ToString('o')
    }) -join "`n"
}
try {
    Import-Module (Join-Path $PSScriptRoot '../PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1') -Force
    $first = New-IccDemoExercise
    $openHandoff = Get-IccDemoHandoff -ExerciseId $first.ExerciseId -RequireCurrent
    Confirm-IccWorkflow ($openHandoff.Contains('No acknowledgment recorded') -and -not $openHandoff.Contains('Action taken: Open.')) 'An Open handoff must accurately describe the absence of acknowledgment.'
    $canonicalView = Get-IccDemoView -Exercise $first -Section Overview
    foreach ($section in @('overview','oVeRvIeW')) {
        Confirm-IccWorkflow ((Get-IccDemoView -Exercise $first -Section $section) -ceq $canonicalView) 'Accepted Overview casing must render the same section.'
    }
    $read = Invoke-IccDemoAction -Action read -ExerciseId $first.ExerciseId -RequireCurrent
    Confirm-IccWorkflow ($read.State.incidentStatus -ceq 'Open' -and $read.Events[-1].action -ceq 'Read') 'Lowercase read must execute a canonical Read.'
    $ack = Invoke-IccDemoAction -Action aCkNoWlEdGe -ExerciseId $first.ExerciseId -RequireCurrent
    Confirm-IccWorkflow ($ack.State.incidentStatus -ceq 'Acknowledged' -and $ack.State.transitionCount -eq 1 -and $ack.Events[-1].action -ceq 'Acknowledge') 'Mixed acknowledgment casing must save one canonical acknowledgment.'
    $repeat = Invoke-IccDemoAction -Action acknowledge -ExerciseId $first.ExerciseId -RequireCurrent
    Confirm-IccWorkflow ($repeat.Events[-1].disposition -ceq 'AlreadyAcknowledged' -and $repeat.State.stateSha256 -ceq $ack.State.stateSha256 -and $repeat.State.acknowledgedAtUtc -ceq $ack.State.acknowledgedAtUtc) 'Lowercase repeats must retain the first acknowledgment.'
    $handoff = Get-IccDemoHandoff -ExerciseId $first.ExerciseId -RequireCurrent
    Confirm-IccWorkflow ($handoff.Contains('Action taken: Acknowledged. The app records acknowledgment in durable server-side state.')) 'The acknowledged handoff must retain its established wording.'
    $next = New-IccDemoExercise
    $before = Get-IccFixtureInventory
    foreach ($action in @('Read','Acknowledge')) {
        $refused = $false
        try { Invoke-IccDemoAction -Action $action -ExerciseId $first.ExerciseId -RequireCurrent | Out-Null }
        catch { $refused = $_.Exception.Message -like '*active rehearsal changed*' }
        Confirm-IccWorkflow $refused 'A current-only native action must reject the previous rehearsal.'
        Confirm-IccWorkflow ((Get-IccFixtureInventory) -ceq $before) 'A stale native action must preserve every fixture file and write time.'
    }
    $refused = $false
    try { Get-IccDemoHandoff -ExerciseId $first.ExerciseId -RequireCurrent | Out-Null }
    catch { $refused = $_.Exception.Message -like '*active rehearsal changed*' }
    Confirm-IccWorkflow $refused 'A current-only native handoff must reject the previous rehearsal.'
    Confirm-IccWorkflow ((Get-IccFixtureInventory) -ceq $before) 'A stale native handoff must preserve the store.'
    $refused = $false
    try { Invoke-IccDemoToolOperation -Action Acknowledge -ExerciseId $first.ExerciseId | Out-Null }
    catch { $refused = $_.Exception.Message -like '*active rehearsal changed*' }
    Confirm-IccWorkflow $refused 'MCP must retain its stale-rehearsal refusal.'
    Confirm-IccWorkflow ((Get-IccFixtureInventory) -ceq $before) 'A stale MCP action must preserve the store.'
    $previousExercise = Get-IccDemoExercise -ExerciseId $first.ExerciseId
    Confirm-IccWorkflow ($previousExercise.State.stateSha256 -ceq $ack.State.stateSha256) 'Non-current exercises must remain readable by ID.'
    Confirm-IccWorkflow ((Get-IccDemoExercise -ExerciseId $next.ExerciseId).State.incidentStatus -ceq 'Open') 'Rejected stale actions must not acknowledge the new exercise.'
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
    $report = [ordered]@{outcome='PASS';checks=$checks;psuRequests=0;scope='Input casing, Open handoff semantics, current-only native actions, stale handoff/MCP refusal and previous exercise preservation; isolated fixture data only.'}
    $report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json') -Encoding utf8
    $report | ConvertTo-Json
} finally { $env:ICC_DEMO_DATA_ROOT = $previousRoot }
