function Invoke-IccDemoToolOperation {
    <#
    .SYNOPSIS
    Inspect, acknowledge, or hand off Acme's current ICC rehearsal.
    .PARAMETER Action
    Inspect reads current facts and adds a read event. Acknowledge changes incident
    state once. Handoff returns a saved-state summary without changing the incident.
    .PARAMETER ExerciseId
    The full ID returned by Inspect. Required for Acknowledge and Handoff.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Inspect','Acknowledge','Handoff')][string]$Action,
        [string]$ExerciseId = ''
    )
    $ErrorActionPreference = 'Stop'
    if ($ExerciseId -and $ExerciseId -cnotmatch '\A[a-f0-9]{32}\z') { throw 'Invalid exercise ID. Inspect the current incident first.' }
    if ($Action -ne 'Inspect' -and -not $ExerciseId) { throw 'Inspect first and supply its exact exercise ID.' }
    $root = Get-IccDemoRoot
    Invoke-IccStoreLock -LockFile (Join-Path $root 'current.lock') -Body {
        $pointer = Join-Path $root 'current.json'
        if (-not [IO.File]::Exists($pointer)) { throw 'Open the ICC app to start a rehearsal first.' }
        $currentId = ([IO.File]::ReadAllText($pointer) | ConvertFrom-Json -DateKind String).exerciseId
        if ($currentId -cnotmatch '\A[a-f0-9]{32}\z') { throw 'The current rehearsal record is invalid.' }
        if ($ExerciseId -and $ExerciseId -cne $currentId) { throw 'The active rehearsal changed. Inspect again before taking action.' }
        $exercise = switch ($Action) {
            'Inspect' { Invoke-IccDemoAction -Action Read -ExerciseId $currentId }
            'Acknowledge' { Invoke-IccDemoAction -Action Acknowledge -ExerciseId $currentId }
            'Handoff' { Get-IccDemoExercise -ExerciseId $currentId }
        }
        $state = $exercise.State
        $disposition = if ($Action -eq 'Handoff') { 'HandoffPrepared' } else { $exercise.Events[-1].disposition }
        [pscustomobject][ordered]@{
            schemaVersion = 1
            callId = [guid]::NewGuid().ToString('N')
            company = 'Acme Inc.'
            demo = $true
            action = $Action
            exerciseId = $currentId
            incidentId = 'DEMO-INC-001'
            service = 'Acme Checkout API'
            latencyMs = 820
            thresholdMs = 500
            severity = 'Warning'
            status = $state.incidentStatus
            disposition = $disposition
            acknowledgedAtUtc = $state.acknowledgedAtUtc
            transitionCount = $state.transitionCount
            stateSha256 = $state.stateSha256
            explicitStateReads = @($exercise.Events | Where-Object { $_.action -eq 'Read' -and $_.incidentStatus -eq 'Acknowledged' -and $_.stateSha256 -eq $state.stateSha256 }).Count
            safeRepeatCount = @($exercise.Events | Where-Object disposition -EQ 'AlreadyAcknowledged').Count
            observedAtUtc = [datetimeoffset]::UtcNow.ToString('o')
            handoff = if ($Action -eq 'Handoff') { Get-IccDemoHandoff -ExerciseId $currentId } else { $null }
            note = 'Acknowledgment records receipt of the alert. The warning remains; no service repair was performed.'
        }
    }
}
