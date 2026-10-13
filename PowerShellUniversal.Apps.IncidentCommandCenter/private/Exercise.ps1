function Get-IccDemoRoot {
    $root = if ($env:ICC_DEMO_DATA_ROOT) { $env:ICC_DEMO_DATA_ROOT }
        else { Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/IncidentCommandCenter' }
    $root = [IO.Path]::GetFullPath($root)
    [void][IO.Directory]::CreateDirectory($root)
    return $root
}

function Invoke-IccStoreLock {
    param([string]$LockFile, [scriptblock]$Body)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $lock = $null
    while ($null -eq $lock) {
        try { $lock = [IO.FileStream]::new($LockFile, 'OpenOrCreate', 'ReadWrite', 'None') }
        catch [IO.IOException] {
            if ($timer.Elapsed.TotalSeconds -ge 5) { throw 'The demo is busy. Wait a moment before trying again.' }
            Start-Sleep -Milliseconds 25
        }
    }
    try { & $Body } finally { $lock.Dispose() }
}

function Write-IccDemoJson {
    param([string]$Path, $Value)
    $pending = $Path + '.' + [guid]::NewGuid().ToString('N') + '.pending'
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 8 -Compress))
    $stream = [IO.FileStream]::new($pending, 'CreateNew', 'Write', 'None')
    try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
    [IO.File]::Move($pending, $Path, $true)
}

function New-IccExerciseRecord {
    param([string]$Root)
    $id = [guid]::NewGuid().ToString('N')
    $path = Join-Path $Root $id
    [void][IO.Directory]::CreateDirectory($path)
    $record = [ordered]@{ schemaVersion = 1; exerciseId = $id; createdAtUtc = [datetimeoffset]::UtcNow.ToString('o'); synthetic = $true }
    Write-IccDemoJson -Path (Join-Path $path 'exercise.json') -Value $record
    Write-IccDemoJson -Path (Join-Path $Root 'current.json') -Value @{ exerciseId = $id }
    return $id
}

function New-IccDemoExercise {
    <#
    .SYNOPSIS
    Starts a fresh shared rehearsal and retains every previous exercise.
    #>
    [CmdletBinding()]
    param()
    $root = Get-IccDemoRoot
    $id = Invoke-IccStoreLock -LockFile (Join-Path $root 'current.lock') -Body { New-IccExerciseRecord -Root $root }
    Get-IccDemoExercise -ExerciseId $id
}

function Resolve-IccExerciseId {
    param([string]$ExerciseId)
    if ($ExerciseId) {
        if ($ExerciseId -cnotmatch '\A[a-f0-9]{32}\z') { throw 'Invalid exercise ID.' }
        return $ExerciseId
    }
    $root = Get-IccDemoRoot
    $pointer = Join-Path $root 'current.json'
    $id = Invoke-IccStoreLock -LockFile (Join-Path $root 'current.lock') -Body {
        if (-not [IO.File]::Exists($pointer)) { New-IccExerciseRecord -Root $root }
        else { ([IO.File]::ReadAllText($pointer) | ConvertFrom-Json -DateKind String).exerciseId }
    }
    if ($id -cnotmatch '\A[a-f0-9]{32}\z') { throw 'The current exercise record is invalid.' }
    return $id
}

function Get-IccDemoExercise {
    <#
    .SYNOPSIS
    Reads an exercise and its durable state. An initial visit creates a demo exercise.
    #>
    [CmdletBinding()]
    param([string]$ExerciseId)
    $id = Resolve-IccExerciseId $ExerciseId
    $path = Join-Path (Get-IccDemoRoot) $id
    $record = [IO.File]::ReadAllText((Join-Path $path 'exercise.json')) | ConvertFrom-Json -DateKind String
    if ($record.schemaVersion -ne 1 -or $record.exerciseId -cne $id -or $record.synthetic -ne $true) { throw 'Invalid exercise record.' }
    $state = Invoke-IccW4State -Root (Join-Path $path 'state') -Action Read -Nonce ([guid]::NewGuid().ToString('N'))
    $eventsPath = Join-Path $path 'actions.json'
    $events = @()
    if ([IO.File]::Exists($eventsPath)) { $events = @([IO.File]::ReadAllText($eventsPath) | ConvertFrom-Json -DateKind String) }
    [pscustomobject]@{
        ExerciseId = $id
        CreatedAtUtc = $record.createdAtUtc
        State = $state
        Events = @($events)
        ReadAtUtc = [datetimeoffset]::UtcNow.ToString('o')
    }
}

function Invoke-IccCurrentExercise {
    param([string]$ExerciseId, [scriptblock]$Operation)
    if ($ExerciseId -cnotmatch '\A[a-f0-9]{32}\z') { throw 'Refresh the dashboard before taking action.' }
    $root = Get-IccDemoRoot
    Invoke-IccStoreLock -LockFile (Join-Path $root 'current.lock') -Body {
        $pointer = Join-Path $root 'current.json'
        if (-not [IO.File]::Exists($pointer)) { throw 'Open the ICC app to start a rehearsal first.' }
        $currentId = ([IO.File]::ReadAllText($pointer) | ConvertFrom-Json -DateKind String).exerciseId
        if ($currentId -cnotmatch '\A[a-f0-9]{32}\z') { throw 'The current rehearsal record is invalid.' }
        if ($currentId -cne $ExerciseId) { throw 'The active rehearsal changed. Refresh the dashboard before taking action.' }
        & $Operation
    }
}

function Invoke-IccDemoAction {
    <#
    .SYNOPSIS
    Reads or acknowledges one demo exercise. Never changes a real service.
    .DESCRIPTION
    Repeated acknowledgment preserves the original timestamp, ID, and state.
    Each explicit action creates an event. This is an app callback, not a PSU automation job.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Read','Acknowledge')][string]$Action,
        [Parameter(Mandatory)][ValidatePattern('\A[a-f0-9]{32}\z')][string]$ExerciseId,
        [switch]$RequireCurrent
    )
    $Action = if ($Action -ieq 'Acknowledge') { 'Acknowledge' } else { 'Read' }
    if ($RequireCurrent) {
        Invoke-IccCurrentExercise -ExerciseId $ExerciseId -Operation { Invoke-IccDemoAction -Action $Action -ExerciseId $ExerciseId }
        return
    }
    $null = Get-IccDemoExercise -ExerciseId $ExerciseId
    $path = Join-Path (Get-IccDemoRoot) $ExerciseId
    Invoke-IccStoreLock -LockFile (Join-Path $path 'actions.lock') -Body {
        $eventsPath = Join-Path $path 'actions.json'
        $events = @()
        if ([IO.File]::Exists($eventsPath)) { $events = @([IO.File]::ReadAllText($eventsPath) | ConvertFrom-Json -DateKind String) }
        if ($events.Count -ge 500) { throw 'This exercise has reached its action limit. Start a new rehearsal.' }
        $parameters = @{ Root = (Join-Path $path 'state'); Action = $Action; Nonce = [guid]::NewGuid().ToString('N') }
        if ($Action -ceq 'Acknowledge') { $parameters.AcknowledgmentId = [guid]::NewGuid().ToString('N') }
        $state = Invoke-IccW4State @parameters
        $events += [pscustomobject]@{
            action = $Action; disposition = $state.disposition
            atUtc = [datetimeoffset]::UtcNow.ToString('o')
            incidentStatus = $state.incidentStatus; stateSha256 = $state.stateSha256
            transitionCount = $state.transitionCount
        }
        Write-IccDemoJson -Path $eventsPath -Value @($events)
    }
    Get-IccDemoExercise -ExerciseId $ExerciseId
}

function Get-IccDemoHandoff {
    <#
    .SYNOPSIS
    Produces a copy-ready operations handoff for the demo exercise.
    #>
    [CmdletBinding()]
    param([string]$ExerciseId, [switch]$RequireCurrent)
    if ($RequireCurrent) {
        Invoke-IccCurrentExercise -ExerciseId $ExerciseId -Operation { Get-IccDemoHandoff -ExerciseId $ExerciseId }
        return
    }
    $exercise = Get-IccDemoExercise -ExerciseId $ExerciseId
    $state = $exercise.State
    $ack = if ($state.incidentStatus -ceq 'Acknowledged') { $state.acknowledgedAtUtc } else { 'Not yet acknowledged' }
    $actionTaken = if ($state.incidentStatus -ceq 'Acknowledged') { 'Acknowledged. The app records acknowledgment in durable server-side state.' }
        else { 'No acknowledgment recorded; the incident remains Open.' }
    $reads = @($exercise.Events | Where-Object { $_.action -ceq 'Read' -and $_.stateSha256 -ceq $state.stateSha256 -and $_.incidentStatus -ceq 'Acknowledged' })
    $repeats = @($exercise.Events | Where-Object disposition -CEQ 'AlreadyAcknowledged')
    @"
ACME INC. — INCIDENT HANDOFF 📋
Exercise: Demo
Service: Acme Checkout API
Incident: DEMO-INC-001
Status: $($state.incidentStatus)
Severity: Warning 🚨 — acknowledgment does not repair a service
Acknowledged at UTC: $ack
Saved-state transitions: $($state.transitionCount)
Explicit persisted-state reads: $($reads.Count)
Safe repeat acknowledgments: $($repeats.Count)

Situation: Acme checkout latency is 820 ms against a 500 ms demo threshold.
Impact: Acme's demo checkout journey may feel slow. No real customers or services are being monitored.
Action taken: $actionTaken
Next owner: Acme operations team.
Next action: Investigate the demo latency signal; keep the warning visible until remediation is separately verified.

This handoff was generated from the saved Acme demo record. No service remediation was performed.
Exercise: $($exercise.ExerciseId)

Une production des Externes de Devolutions
"@
}
