#Requires -Version 7.5.4
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot ('../output/state-recovery-' + [guid]::NewGuid().ToString('N'))),
    [string]$ModulePath = (Join-Path $PSScriptRoot '../PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
)
# Offline only: the ICC data module, local runspaces, synthetic files and UI shims.
# No management module, PSU transport, browser, credentials or resource cleanup.
$ErrorActionPreference = 'Stop'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$ModulePath = [IO.Path]::GetFullPath($ModulePath)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a fresh output directory for these checks.' }
$null = New-Item -ItemType Directory -Path $OutputDirectory
$previousRoot = $env:ICC_DEMO_DATA_ROOT
$cases = [Collections.Generic.List[object]]::new()
$script:checks = 0
function Confirm-IccState($Condition, [string]$Message) {
    $script:checks++
    if (-not $Condition) { throw $Message }
}
function Test-IccStateCase([string]$Name, [scriptblock]$Body) {
    try { & $Body; $cases.Add([pscustomobject]@{name=$Name;outcome='PASS'}) }
    catch { $cases.Add([pscustomobject]@{name=$Name;outcome='FAIL';error=$_.Exception.Message;stack=$_.ScriptStackTrace}) }
}
function New-IccStateFixture([string]$Name) {
    $env:ICC_DEMO_DATA_ROOT = Join-Path $OutputDirectory $Name
    if (Test-Path -LiteralPath $env:ICC_DEMO_DATA_ROOT) { throw 'Fixture already exists.' }
    New-IccDemoExercise
}
function Get-IccStateInventory {
    (@(Get-ChildItem -LiteralPath $env:ICC_DEMO_DATA_ROOT -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName + '|' + (Get-FileHash -LiteralPath $_.FullName).Hash + '|' + $_.LastWriteTimeUtc.Ticks
    }) -join "`n")
}
try {
    Import-Module $ModulePath -Force
    Test-IccStateCase 'Getters wait for the timeline writer lock' {
        $first = New-IccStateFixture 'reader-lock'
        $null = Invoke-IccDemoAction -Action Read -ExerciseId $first.ExerciseId
        $path = Join-Path $env:ICC_DEMO_DATA_ROOT $first.ExerciseId
        $lock = [IO.FileStream]::new((Join-Path $path 'actions.lock'),'OpenOrCreate','ReadWrite','None')
        $ready = [Threading.ManualResetEventSlim]::new($false)
        $worker = [Management.Automation.PowerShell]::Create()
        try {
            $null = $worker.AddScript('param($ModulePath,$Id,$Ready); Import-Module $ModulePath; $Ready.Set(); Get-IccDemoExercise -ExerciseId $Id').AddArgument($ModulePath).AddArgument($first.ExerciseId).AddArgument($ready)
            $pending = $worker.BeginInvoke()
            Confirm-IccState ($ready.Wait(5000)) 'Reader worker did not become ready.'
            $completedWhileLocked = $pending.AsyncWaitHandle.WaitOne(300)
            $lock.Dispose(); $lock = $null
            $read = @($worker.EndInvoke($pending))
            Confirm-IccState (-not $worker.HadErrors) 'Reader worker failed.'
            Confirm-IccState (-not $completedWhileLocked) 'Getter bypassed the timeline writer lock.'
            Confirm-IccState ($read.Count -eq 1 -and $read[0].State.incidentStatus -ceq 'Open') 'Reader must resume with its coherent Open snapshot.'
        } finally {
            if ($lock) { $lock.Dispose() }
            $worker.Dispose(); $ready.Dispose()
        }
    }
    Test-IccStateCase 'Missing acknowledgment blocks all public read and action paths without rewriting files' {
        $first = New-IccStateFixture 'missing-record'
        $ack = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId
        $path = [IO.Path]::GetFullPath((Join-Path $env:ICC_DEMO_DATA_ROOT ($first.ExerciseId + '/state/DEMO-INC-001.json')))
        if (-not $path.StartsWith($OutputDirectory + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped output directory.' }
        [IO.File]::Move($path,$path+'.preserved')
        $before = Get-IccStateInventory
        foreach ($operation in @('Get','Read','Acknowledge','NativeHandoff','Inspect','McpAcknowledge','McpHandoff')) {
            $failure = $null
            try {
                switch ($operation) {
                    'Get' { $null = Get-IccDemoExercise -ExerciseId $first.ExerciseId }
                    'Read' { $null = Invoke-IccDemoAction -Action Read -ExerciseId $first.ExerciseId -RequireCurrent }
                    'Acknowledge' { $null = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId -RequireCurrent }
                    'NativeHandoff' { $null = Get-IccDemoHandoff -ExerciseId $first.ExerciseId -RequireCurrent }
                    'Inspect' { $null = Invoke-IccDemoToolOperation -Action Inspect -ExerciseId $first.ExerciseId }
                    'McpAcknowledge' { $null = Invoke-IccDemoToolOperation -Action Acknowledge -ExerciseId $first.ExerciseId }
                    'McpHandoff' { $null = Invoke-IccDemoToolOperation -Action Handoff -ExerciseId $first.ExerciseId }
                }
            } catch { $failure = $_.Exception.Message }
            Confirm-IccState ($failure -like '*saved acknowledgment is missing*') ($operation + ' must report missing acknowledgment data.')
            Confirm-IccState ((Get-IccStateInventory) -ceq $before) ($operation + ' must preserve the damaged store and its write times.')
        }
        [IO.File]::Copy($path+'.preserved',$path)
        $restored = Get-IccDemoExercise -ExerciseId $first.ExerciseId
        Confirm-IccState ($restored.State.acknowledgmentId -ceq $ack.State.acknowledgmentId -and $restored.State.acknowledgedAtUtc -ceq $ack.State.acknowledgedAtUtc) 'Restoring the original file must recover the original acknowledgment.'
        $repeat = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId -RequireCurrent
        Confirm-IccState ($repeat.Events[-1].disposition -ceq 'AlreadyAcknowledged' -and $repeat.State.stateSha256 -ceq $ack.State.stateSha256) 'Repetition after verified recovery must preserve the first saved response.'
    }
    Test-IccStateCase 'The state engine refuses a required acknowledgment that is missing at its own lock' {
        $first = New-IccStateFixture 'required-state'
        $stateRoot = Join-Path $env:ICC_DEMO_DATA_ROOT ($first.ExerciseId+'/state')
        $before = Get-IccStateInventory
        $failure = $null
        $loaded = Get-Module PowerShellUniversal.Apps.IncidentCommandCenter
        try {
            & $loaded {
                param($Root)
                Invoke-IccW4State -Root $Root -Action Acknowledge -Nonce ([guid]::NewGuid().ToString('N')) -AcknowledgmentId ([guid]::NewGuid().ToString('N')) -RequireExisting
            } $stateRoot | Out-Null
        } catch { $failure = $_.Exception.Message }
        Confirm-IccState ($failure -like '*saved acknowledgment is missing*') 'The state lock must enforce the required-existing-record condition.'
        Confirm-IccState (-not [IO.File]::Exists((Join-Path $stateRoot 'DEMO-INC-001.json'))) 'The state guard must not manufacture a replacement acknowledgment.'
        Confirm-IccState ((Get-IccStateInventory) -ceq $before) 'The state guard must preserve all fixture files and write times.'
    }
    Test-IccStateCase 'An acknowledgment remains usable if its event could not be written' {
        $first = New-IccStateFixture 'event-write-failure'
        $null = Invoke-IccDemoAction -Action Read -ExerciseId $first.ExerciseId
        $loaded = Get-Module PowerShellUniversal.Apps.IncidentCommandCenter
        & $loaded {
            $script:IccOriginalJsonWriter = ${function:Write-IccDemoJson}
            function script:Write-IccDemoJson {
                param([string]$Path,$Value)
                if ([IO.Path]::GetFileName($Path) -ceq 'actions.json') { throw 'Injected timeline publication failure.' }
                & $script:IccOriginalJsonWriter @PSBoundParameters
            }
        }
        $failure = $null
        try { $null = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId }
        catch { $failure = $_.Exception.Message }
        finally { Import-Module $ModulePath -Force }
        $saved = Get-IccDemoExercise -ExerciseId $first.ExerciseId
        Confirm-IccState ($failure -like '*Acknowledgment is saved*timeline event*') 'A post-commit failure must explain that acknowledgment is saved.'
        Confirm-IccState ($saved.State.incidentStatus -ceq 'Acknowledged' -and $saved.Events.Count -eq 1) 'The authoritative acknowledgment must survive the failed timeline write.'
        $repeat = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId
        Confirm-IccState ($repeat.Events[-1].disposition -ceq 'AlreadyAcknowledged' -and $repeat.State.stateSha256 -ceq $saved.State.stateSha256) 'Retry must preserve the saved acknowledgment.'
    }
    Test-IccStateCase 'Concurrent readers and acknowledgments return coherent snapshots' {
        $first = New-IccStateFixture 'concurrent-snapshots'
        $pool = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,8)
        $pool.Open()
        $workers = @()
        try {
            foreach ($index in 1..10) {
                $worker = [Management.Automation.PowerShell]::Create()
                $worker.RunspacePool = $pool
                $kind = if ($index -le 8) { 'Acknowledge' } else { 'Read' }
                $null = $worker.AddScript(@'
param($ModulePath,$Id,$Kind)
Import-Module $ModulePath
if ($Kind -eq 'Acknowledge') {
    $result = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $Id
    [pscustomobject]@{kind=$Kind;disposition=$result.Events[-1].disposition;hash=$result.State.stateSha256;coherent=($result.State.transitionCount -eq 1)}
} else {
    foreach ($iteration in 1..8) {
        $result = Get-IccDemoExercise -ExerciseId $Id
        $ackEvents = @($result.Events | Where-Object disposition -EQ 'Acknowledged')
        [pscustomobject]@{kind=$Kind;coherent=($result.State.incidentStatus -ceq 'Open' -and $ackEvents.Count -eq 0) -or ($result.State.incidentStatus -ceq 'Acknowledged' -and $ackEvents.Count -eq 1 -and $ackEvents[0].stateSha256 -ceq $result.State.stateSha256)}
    }
}
'@).AddArgument($ModulePath).AddArgument($first.ExerciseId).AddArgument($kind)
                $workers += [pscustomobject]@{worker=$worker;pending=$worker.BeginInvoke()}
            }
            $frames = foreach ($entry in $workers) {
                $entry.worker.EndInvoke($entry.pending)
                Confirm-IccState (-not $entry.worker.HadErrors) 'Concurrent worker reported an error.'
            }
            $acks = @($frames | Where-Object kind -EQ 'Acknowledge')
            Confirm-IccState ($acks.Count -eq 8 -and @($acks | Where-Object disposition -EQ 'Acknowledged').Count -eq 1 -and @($acks | Where-Object disposition -EQ 'AlreadyAcknowledged').Count -eq 7) 'Concurrent callers must receive their own correct acknowledgment disposition.'
            Confirm-IccState (@($acks.hash | Sort-Object -Unique).Count -eq 1) 'Concurrent acknowledgments must preserve one hash.'
            Confirm-IccState (@($frames | Where-Object { -not $_.coherent }).Count -eq 0) 'Every reader/action snapshot must agree with its timeline.'
            Confirm-IccState ((Get-IccDemoExercise -ExerciseId $first.ExerciseId).Events.Count -eq 8) 'Concurrent calls must retain all eight action events.'
        } finally {
            foreach ($entry in $workers) { $entry.worker.Dispose() }
            $pool.Dispose()
        }
    }
    # Execute the actual dashboard callback with local UI shims; no PSU UI is loaded.
    function New-UDApp { param($Title,[scriptblock]$Content) $null = & $Content }
    function New-UDStyle { param($Style,[scriptblock]$Content) $null = & $Content }
    function New-UDElement { param($Tag,$Attributes,[scriptblock]$Content) $null = & $Content }
    function New-UDDynamic { param($Id,[scriptblock]$Content) $null = & $Content }
    function New-UDHtml { param($Markup) }
    function New-UDButton { param($Id,$Text,$Variant,$Color,[scriptblock]$OnClick) $global:IccTestButtons[$Id] = $OnClick }
    function Show-UDToast { param($Message,$Duration) $global:IccTestToasts.Add([string]$Message) }
    function Sync-UDElement { param($Id) }
    $null = New-PSDrive -Name Cache -PSProvider Variable -Root ''
    $null = New-PSDrive -Name Session -PSProvider Variable -Root ''
    Set-Variable -Name IccShowcaseModuleRoot -Scope Global -Value (Split-Path -Parent $ModulePath)
    Set-Variable -Name IccShowcaseCss -Scope Global -Value ''
    Test-IccStateCase 'Native Verify distinguishes an absent acknowledgment from a persisted response' {
        $first = New-IccStateFixture 'native-verify'
        $global:IccTestButtons = @{}
        $global:IccTestToasts = [Collections.Generic.List[string]]::new()
        Set-Variable -Name IccExerciseId -Scope Global -Value $first.ExerciseId
        & (Join-Path (Split-Path -Parent $ModulePath) 'dashboard/IncidentCommandCenter.ps1')
        & ($global:IccTestButtons['icc-verify'])
        Confirm-IccState ($global:IccTestToasts[-1] -like 'No acknowledgment*') 'Verify before acknowledgment must say that no acknowledgment exists.'
        Confirm-IccState (-not [IO.File]::Exists((Join-Path $env:ICC_DEMO_DATA_ROOT ($first.ExerciseId+'/state/DEMO-INC-001.json')))) 'An Open verification must not manufacture an acknowledgment file.'
        $null = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId
        & ($global:IccTestButtons['icc-verify'])
        Confirm-IccState ($global:IccTestToasts[-1] -like '*loaded the saved acknowledgment from disk*') 'Verify after acknowledgment must describe the actual disk read.'
    }
    Test-IccStateCase 'Open read timeline copy does not claim a nonexistent state file' {
        $first = New-IccStateFixture 'open-read-copy'
        $read = Invoke-IccDemoAction -Action Read -ExerciseId $first.ExerciseId
        $details = Get-IccDemoView -Exercise $read -Section Details
        $overview = Get-IccDemoView -Exercise $read -Section Overview
        Confirm-IccState ($details.Contains('No acknowledgment saved yet') -and -not $details.Contains('Loaded Open from the server-side state file.')) 'An initial Read must describe the absent acknowledgment accurately.'
        Confirm-IccState (-not $overview.Contains('Verified from disk')) 'An initial Read must not set the verification badge.'
        $null = Invoke-IccDemoAction -Action Acknowledge -ExerciseId $first.ExerciseId
        $verified = Invoke-IccDemoAction -Action Read -ExerciseId $first.ExerciseId
        Confirm-IccState ((Get-IccDemoView -Exercise $verified -Section Overview).Contains('Verified from disk')) 'A later matching persisted read must still verify the response.'
        Confirm-IccState ((Get-IccDemoView -Exercise $verified -Section Details).Contains('Loaded Acknowledged from the server-side state file.')) 'Acknowledged reads must retain accurate saved-state wording.'
    }
} finally { $env:ICC_DEMO_DATA_ROOT = $previousRoot }
$failed = @($cases | Where-Object outcome -EQ 'FAIL')
$report = [ordered]@{outcome=if($failed.Count){'FAIL'}else{'PASS'};checks=$script:checks;cases=$cases.ToArray();psuRequests=0;scope='Timeline locking, damaged-store refusal, post-commit error reporting, concurrent snapshots and the actual Verify callback under UI shims.'}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json')
$report | ConvertTo-Json -Depth 8
if ($failed.Count) { exit 1 }
