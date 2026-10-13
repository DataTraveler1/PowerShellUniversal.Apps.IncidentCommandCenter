#Requires -Version 7.5.4
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot ('../output/test-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$module = Join-Path $package 'PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1'
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$oldRoot = $env:ICC_DEMO_DATA_ROOT
$env:ICC_DEMO_DATA_ROOT = [IO.Path]::GetFullPath((Join-Path $OutputDirectory 'data'))
$script:checks = 0
function Assert-Icc($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
try {
    foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object Extension -In @('.ps1','.psm1','.psd1')) {
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        Assert-Icc ($parseErrors.Count -eq 0) ('PowerShell parse failure: ' + $file.Name)
    }
    Import-Module $module -Force
    $initial = Get-IccDemoExercise
    Assert-Icc ($initial.State.incidentStatus -ceq 'Open' -and $initial.Events.Count -eq 0) 'First exercise should start Open without actions'
    $ack = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $initial.ExerciseId
    Assert-Icc ($ack.State.incidentStatus -ceq 'Acknowledged' -and $ack.State.transitionCount -eq 1) 'Acknowledgment should produce one transition'
    $statePath = Join-Path $env:ICC_DEMO_DATA_ROOT ($initial.ExerciseId + '/state/DEMO-INC-001.json')
    $bytesBefore = [Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath))
    $writeTimeBefore = [IO.File]::GetLastWriteTimeUtc($statePath)
    $read = Invoke-IccDemoAction -Action Read -ExerciseId $initial.ExerciseId
    Assert-Icc ($read.State.stateSha256 -ceq $ack.State.stateSha256 -and $read.Events.Count -eq 2) 'Separate read should match saved state'
    $repeat = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $initial.ExerciseId
    Assert-Icc ($repeat.Events[-1].disposition -ceq 'AlreadyAcknowledged') 'Repeat should report AlreadyAcknowledged'
    Assert-Icc ($repeat.State.acknowledgmentId -ceq $ack.State.acknowledgmentId -and $repeat.State.acknowledgedAtUtc -ceq $ack.State.acknowledgedAtUtc) 'Repeat must retain first identity and timestamp'
    Assert-Icc ([Convert]::ToBase64String([IO.File]::ReadAllBytes($statePath)) -ceq $bytesBefore -and [IO.File]::GetLastWriteTimeUtc($statePath) -eq $writeTimeBefore) 'Repeat must not rewrite the state file'
    $summary = Get-IccDemoHandoff -ExerciseId $initial.ExerciseId
    Assert-Icc ($summary.Contains('Explicit persisted-state reads: 1') -and $summary.Contains('Safe repeat acknowledgments: 1')) 'Handoff should describe actual actions'
    $view = Get-IccDemoView -Exercise $repeat -Section Overview
    Assert-Icc ($view.Contains('Acknowledged') -and $view.Contains('Verified from disk') -and $view.Contains('WARNING')) 'UI source should distinguish acknowledgment from warning'
    $next = New-IccDemoExercise
    Assert-Icc ($next.ExerciseId -cne $initial.ExerciseId -and $next.State.incidentStatus -ceq 'Open') 'New rehearsal must use a new store'
    Assert-Icc ((Get-IccDemoExercise -ExerciseId $initial.ExerciseId).State.stateSha256 -ceq $ack.State.stateSha256) 'Previous rehearsal must remain unchanged'
    Assert-Icc ((Get-IccDemoExercise).ExerciseId -ceq $next.ExerciseId) 'Current exercise pointer should survive another read'
    $rejected = $false
    try { Get-IccDemoExercise -ExerciseId '../outside' | Out-Null } catch { $rejected = $true }
    Assert-Icc $rejected 'Exercise IDs must reject traversal'
    $worker = Join-Path $OutputDirectory 'read-persisted.ps1'
    [IO.File]::WriteAllText($worker, 'param($ModulePath,$ExerciseId); Import-Module $ModulePath; (Get-IccDemoExercise -ExerciseId $ExerciseId).State.stateSha256', [Text.UTF8Encoding]::new($false))
    $newProcessHash = & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $worker $module $initial.ExerciseId
    Assert-Icc ($LASTEXITCODE -eq 0 -and $newProcessHash.Trim() -ceq $ack.State.stateSha256) 'Fresh process must read the same persisted acknowledgment'
    $report = [ordered]@{ outcome = 'PASS'; checks = $script:checks; atUtc = [datetimeoffset]::UtcNow.ToString('o'); psuRequests = 0; scope = 'State transitions, rehearsal isolation, handoff and PowerShell syntax; visual review is separate.' }
    $report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json')
    $report | ConvertTo-Json
} finally {
    $env:ICC_DEMO_DATA_ROOT = $oldRoot
}
