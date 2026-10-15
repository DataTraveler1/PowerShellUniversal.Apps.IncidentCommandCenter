# Architecture

ICC is a learning example of connecting an AI service to PowerShell Universal
with Model Context Protocol (MCP), using a shared incident-response rehearsal on
one Windows PSU 2026.3.3 server. This document describes ICC 0.1.3. Isolated
native/MCP runtime qualification and actual packaged app/tool installation on
refreshed PSU 2026.3.3 passed.

The AI service supplies the model and conversation through an MCP-capable client.
PSU authenticates the connection and runs exposed PowerShell tools on the server.
Native buttons run module functions in the app process. The optional MCP tool
calls the same module from PSU automation jobs. The dashboard contains no
embedded model client. Commercial AI services and organization-provided models
need a compatible application and tool-capable model; only Codex has been tested
with ICC. See the [connection guide](MCP.md#choose-your-ai-service-and-client).

## State and locking

Each exercise has a creation record, acknowledgment file and explicit-action
timeline. `current.json` selects the active rehearsal shared by all viewers.
**New rehearsal** creates a separate exercise and retains previous data.

Acknowledgment has one transition: Open to Acknowledged. An exclusive file lock
serializes it, and the first response is published atomically. Repeats return the
saved response without rewriting it. The action lock covers both readers and
writers of the state/timeline snapshot, including an action's returned result.
This prevents an ordinary Windows timeline reader from blocking atomic file
replacement and keeps concurrent callers' dispositions separate. Lock order is
current pointer when required, then actions, then acknowledgment state.
“Verified from disk” requires an explicit read matching the saved acknowledgment.
An initial Open read explicitly says that no acknowledgment was saved yet.

Acknowledgment and timeline are separate records. Interruption between writing
the acknowledgment and its event can leave a response without a timeline entry.
The acknowledgment is authoritative; the timeline is a demo activity list.
If its event cannot be written after acknowledgment commits, the error explicitly
says acknowledgment is saved. Inspect the saved response before retrying.

If retained actions reference an acknowledgment whose file is absent, reads,
actions and Handoff stop with a complete-backup recovery message. The state lock
also refuses to recreate a record that a caller requires to exist. No repair is
inferred from the timeline. Loss of both the acknowledgment and every reference
to it cannot be distinguished from an untouched exercise by this check; it is
not a replacement for complete backups. See [recovery](UPGRADE.md#missing-acknowledgment-data).

Each native Acknowledge, Verify and Handoff endpoint captures its rendered
exercise ID in its argument list; controls have exercise-specific IDs. A newer
view cannot retarget an older button by replacing Session data. These actions
hold the current-pointer lock while checking
the displayed exercise and operating. MCP follows the same current-only policy.
Direct backend calls without `-RequireCurrent` can access a specified non-current
exercise. Creating a native handoff marks step 3 complete only in that browser
session; it adds no event or transition.

## Shared store

The default root is `%ProgramData%\PowerShellUniversal\IncidentCommandCenter`.
App and automation processes must share that root and have the required file
access. `ICC_DEMO_DATA_ROOT` selects another root, as the offline tests do.
Store getters can create the initial exercise; Inspect records a Read event.

Code is installed separately under
`%ProgramData%\PowerShellUniversal\Showcases\IncidentCommandCenter\0.1.3`.
Updating code does not reset exercise data.

## MCP

Inspect resolves the current exercise. Acknowledge and Handoff require its full
ID and reject stale IDs. Each result contains bounded demo facts and a unique
callId; PSU job output provides a separate result to compare. The tool cannot run
arbitrary commands, repair services, send messages or start another rehearsal.

## Limits

- One server and one shared active exercise, without multi-node coordination.
- Fixed demo signals, without monitoring, scheduling, escalation or remediation.
- Existing Administrator access; installers create no identity, role or token.
- Acknowledgment records receipt without attributing it to a particular person.
- Up to 500 explicit actions per exercise; the app shows the latest eight plus creation.
- No automatic retention scheduler or deletion.
- The 0.1.3 runtime qualification used Windows Server 2019, PSU/module 2026.3.3, PowerShell 7.6.6 and Codex CLI 0.162.0-alpha.17.2. Actual packaged installation also passed on refreshed PSU 2026.3.3.

The app includes no external fonts, telemetry calls, JavaScript packages or
monitoring APIs.

## Removal

For updates or partial installations, use [Updating and recovery](UPGRADE.md).
For removal, select the exact instance and inventory ICC resources first.
Disconnect the client, stop the ICC app and remove **Incident Command Center**
in PSU administration. Remove **ICC_Demo_Incident** and **icc-demo-mcp.ps1** only
if installed and selected for removal.

Removing definitions leaves code and exercise data intact. Preserve desired
exercises, verify the resolved directories, then remove only the selected ICC
directories. Never remove the shared PSU data root. Installers retain partial
resources on failure and perform no automatic cleanup.

See the [README](../README.md) and [MCP guide](MCP.md).
