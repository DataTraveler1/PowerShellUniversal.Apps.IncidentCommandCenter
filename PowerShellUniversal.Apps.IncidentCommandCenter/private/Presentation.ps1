function Get-IccDemoView {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Exercise, [ValidateSet('Overview','Details')][string]$Section, [switch]$HandoffPrepared)
    $state = $Exercise.State
    $encode = { param($value) [Net.WebUtility]::HtmlEncode([string]$value) }
    $acknowledged = $state.incidentStatus -ceq 'Acknowledged'
    $reads = @($Exercise.Events | Where-Object { $_.action -ceq 'Read' -and $_.incidentStatus -ceq 'Acknowledged' -and $_.stateSha256 -ceq $state.stateSha256 })
    $repeats = @($Exercise.Events | Where-Object disposition -CEQ 'AlreadyAcknowledged')
    $statusClass = if ($acknowledged) { 'icc-green' } else { 'icc-amber' }
    $statusText = if ($acknowledged) { 'Acknowledged ✅' } else { 'Needs attention 👀' }
    $ackTime = if ($acknowledged) { [datetimeoffset]::Parse($state.acknowledgedAtUtc).ToString('HH:mm:ss') + ' UTC' } else { 'Waiting for an operator' }
    $verification = if ($reads.Count) { 'Verified from disk' } else { 'Not checked yet' }
    $shortId = $Exercise.ExerciseId.Substring(0, 8).ToUpperInvariant()
    if ($Section -ieq 'Overview') {
        return @"
<header class="icc-header">
  <div class="icc-brand"><div class="icc-logomark" aria-hidden="true"><span></span><span></span><span></span><span></span></div><div><div class="icc-eyebrow">ACME INC. / OPERATIONS</div><h1>Incident Command Center</h1></div></div>
  <div class="icc-header-right"><span class="icc-demo">DEMO</span><span class="icc-exercise">Exercise $shortId</span></div>
</header>
<div class="icc-intro"><div><span class="icc-kicker">ACME'S OPERATIONS DESK</span><h2>See the signal. Own the response.</h2><p>Keep Acme Inc. moving, from the first alert to the next shift.</p></div><span class="icc-platform">Built with PowerShell Universal</span></div>
<section class="icc-signals" aria-label="Acme Inc. demo service signals">
 <article class="icc-signal icc-signal-focus"><div class="icc-signal-top"><span>Checkout API</span><span class="icc-dot icc-dot-amber"></span></div><div class="icc-signal-number">820 <small>ms</small></div><div class="icc-signal-caption">Above the 500 ms demo threshold</div><div class="icc-mini-bars" aria-hidden="true"><i style="height:20%"></i><i style="height:28%"></i><i style="height:24%"></i><i style="height:37%"></i><i style="height:52%"></i><i style="height:47%"></i><i style="height:67%"></i><i style="height:82%"></i><i style="height:75%"></i><i style="height:92%"></i><i style="height:85%"></i><i style="height:98%"></i></div></article>
 <article class="icc-signal"><div class="icc-signal-top"><span>Inventory service</span><span class="icc-dot"></span></div><div class="icc-signal-number">128 <small>ms</small></div><div class="icc-signal-caption">Within the demo threshold</div><div class="icc-signal-foot">Looking good</div></article>
 <article class="icc-signal"><div class="icc-signal-top"><span>Payment gateway</span><span class="icc-dot"></span></div><div class="icc-signal-number">99.98<small>%</small></div><div class="icc-signal-caption">Demo availability</div><div class="icc-signal-foot">All systems go</div></article>
</section>
<section class="icc-incident">
 <div class="icc-incident-main"><div class="icc-incident-label"><span class="icc-priority">WARNING 🚨</span><span>DEMO-INC-001</span><span class="icc-rule"></span><span>Acme checkout</span></div><h2>Checkout is slower than expected.</h2><p>Acme's shoppers are waiting. Acknowledge the alert, confirm that your response is saved, and leave the next operator a useful handoff.</p><div class="icc-statusline"><span class="icc-status $statusClass">$statusText</span><span class="icc-warning-note">The warning stays visible until a repair is separately verified.</span></div></div>
 <aside class="icc-incident-aside"><span class="icc-kicker">RESPONSE AT A GLANCE</span><dl><div><dt>Acknowledgment</dt><dd>$ackTime</dd></div><div><dt>Saved-state transitions</dt><dd>$($state.transitionCount)</dd></div><div><dt>Persistence</dt><dd>$verification</dd></div><div><dt>Safe repeat actions</dt><dd>$($repeats.Count)</dd></div></dl></aside>
</section>
"@
    }
    $rows = '<li class="icc-timeline-item"><span class="icc-timeline-dot"></span><div><strong>Demo incident opened</strong><p>Acme checkout latency crossed the demo threshold.</p></div><time>' + [datetimeoffset]::Parse($Exercise.CreatedAtUtc).ToString('HH:mm:ss') + '</time></li>'
    foreach ($event in @($Exercise.Events | Select-Object -Last 8)) {
        $title, $detail = switch ($event.disposition) {
            'Acknowledged' { 'Incident acknowledged', 'Acknowledgment recorded. The warning remains; no service repair was performed.' }
            'AlreadyAcknowledged' { 'Repeat handled safely', 'The original acknowledgment, timestamp, and saved state were preserved.' }
            default {
                if ($event.incidentStatus -ceq 'Open' -and -not $event.stateSha256) {
                    'No acknowledgment saved yet', 'No acknowledgment record existed when this read ran. Acknowledge the incident before verifying its saved response.'
                } else { 'Saved state read independently', ('Loaded ' + $event.incidentStatus + ' from the server-side state file.') }
            }
        }
        $rows += '<li class="icc-timeline-item"><span class="icc-timeline-dot"></span><div><strong>' + (& $encode $title) + '</strong><p>' + (& $encode $detail) + '</p></div><time>' + [datetimeoffset]::Parse($event.atUtc).ToString('HH:mm:ss') + '</time></li>'
    }
    $firstStep = if ($acknowledged) { 'icc-step-done' } else { 'icc-step-active' }
    $secondStep = if ($reads.Count) { 'icc-step-done' } elseif ($acknowledged) { 'icc-step-active' } else { '' }
    $thirdStep = if ($HandoffPrepared) { 'icc-step-done' } elseif ($reads.Count) { 'icc-step-active' } else { '' }
    $hash = if ($state.stateSha256) { & $encode $state.stateSha256 } else { 'No acknowledgment record has been written.' }
    return @"
<section class="icc-bottom">
 <article class="icc-panel"><div class="icc-panel-heading"><div><span class="icc-kicker">A SMALL, USEFUL RUNBOOK</span><h3>Make the response repeatable.</h3></div><span class="icc-pill">3 steps</span></div>
  <ol class="icc-runbook"><li class="$firstStep"><span class="icc-step">01</span><div><strong>Acknowledge the incident</strong><p>Record that an operator has seen the signal. Keep severity separate from acknowledgment.</p></div></li><li class="$secondStep"><span class="icc-step">02</span><div><strong>Verify the saved response</strong><p>Read the persisted record again. Repeat acknowledgment to demonstrate that it does not create a second transition.</p></div></li><li class="$thirdStep"><span class="icc-step">03</span><div><strong>Hand off with context</strong><p>Generate a concise summary with the situation, completed actions, verification and next owner.</p></div></li></ol>
 <div class="icc-callout"><strong>Rehearse as often as you need.</strong><p>New rehearsal opens a separate exercise. Earlier acknowledgments remain saved.</p></div>
 </article>
 <article class="icc-panel"><div class="icc-panel-heading"><div><span class="icc-kicker">WHAT ACTUALLY HAPPENED</span><h3>Response timeline</h3></div><span class="icc-pill">UTC</span></div><ol class="icc-timeline">$rows</ol><p class="icc-small">Shows the most recent eight explicit actions in this exercise.</p></article>
</section>
<details class="icc-evidence"><summary>Under the hood: persistence, evidence and MCP</summary><div class="icc-evidence-grid"><div><h4>Real server-side state</h4><p>Native buttons and the optional ICC_Demo_Incident MCP tool share this rehearsal. A file lock and atomic publication protect the original acknowledgment. Explicit reads return the saved record.</p><p><strong>Current saved-state SHA-256</strong></p><code>$hash</code></div><div><h4>Ask the assistant. See the result.</h4><p>With the optional tool installed, an AI assistant can inspect this incident, acknowledge it, verify the saved response, and prepare a handoff through PSU MCP.</p><p>Chat runs beside this dashboard. Refresh after a chat action to see the same saved result. Acknowledgment records receipt; the warning remains until a repair is separately verified.</p></div></div></details>
<footer class="icc-footer"><span>ACME INC. · INCIDENT COMMAND CENTER <b>0.1.2</b></span><span>Demo · Target: PSU 2026.3.3</span><span class="icc-production">Une production des <strong>Externes de Devolutions</strong></span></footer>
"@
}
