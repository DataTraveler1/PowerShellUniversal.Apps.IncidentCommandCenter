# Incident Command Center

**ICC 0.1.2 community preview.** The [0.1.2 release](https://github.com/DataTraveler1/PowerShellUniversal.Apps.IncidentCommandCenter/releases/tag/v0.1.2)
contains three corrections from the independent 0.1.1 review. Validation of these
corrections is offline only; no new live PSU, MCP-client or visual acceptance is
claimed. The retained live baseline and screenshot are from 0.1.1. See
[release notes and change history](RELEASE-NOTES.md).

A working demonstration of PowerShell Universal's **Model Context Protocol (MCP)**
feature, built around an incident-response rehearsal at fictional **Acme Inc.**
Connect an external MCP-capable assistant to PSU, then inspect a warning,
acknowledge it, verify saved state and prepare a handoff.

## FAQ

<a name="why-does-this-exist"></a>

### Why does this exist? 💡

ICC demonstrates **PowerShell Universal's MCP feature** with a working example
you can inspect and try. An external assistant discovers and calls
**ICC_Demo_Incident**; PSU runs the PowerShell and stores the result. The incident
rehearsal gives that demonstration a concrete scenario, and the dashboard makes
the same saved state visible.

<a name="how-do-i-jump-in-and-use-it-now"></a>

### How do I jump in and use it NOW? 🤔

On a compatible Windows PSU server:

1. Download `IncidentCommandCenter-0.1.2.zip` from the
   [0.1.2 preview release](https://github.com/DataTraveler1/PowerShellUniversal.Apps.IncidentCommandCenter/releases/tag/v0.1.2)
   and extract it. The release also supplies a source manifest and SHA-256 checksums.
2. Follow [Install](#install) below, then open `/incident-command-center`
   on your PSU server and sign in as an Administrator.
3. Follow [MCP setup and usage](docs/MCP.md) to register **ICC_Demo_Incident**
   and connect your assistant.
4. Try the prompt below, then refresh the dashboard to see the saved result.

If ICC is already installed, open the existing app and follow
[Updating and recovery](docs/UPGRADE.md) before rerunning an installer.

<a name="what-do-i-need"></a>

### What do I need? 🧰

Windows, **PSU 2026.3.3**, matching **Devolutions.PowerShellUniversal 2026.3.3**,
**PowerShell 7.5.4 or later**, and an existing Administrator app token.
PSU also needs an app-capable license and its **PowerShell 7** environment enabled.
The [installation section](#install) supplies the command and local module path.

<a name="do-i-need-an-ai-account-or-api-key"></a>

### Do I need an AI account or API key? 🤖

The native dashboard works without an AI account or external API. The MCP demo
uses your assistant's existing model access and a PSU Administrator app token.
In PSU, **Disable AI Features** must be off for the MCP endpoint to be available.
Keep tokens in the client's supported local secret mechanism.

<a name="what-should-i-ask-the-assistant"></a>

### What should I ask the assistant? 💬

> Use ICC_Demo_Incident. Inspect the active rehearsal first and keep its full
> exerciseId for later calls. Acknowledge the warning, inspect the saved state,
> acknowledge it again, inspect once more, and prepare a handoff. Stop if a tool
> call fails. Acknowledgment records receipt; it does not repair a service.

See the [guided conversation](docs/MCP.md#demonstrate-the-conversation) for the
expected results. Refresh the dashboard after tool calls.

<a name="is-this-monitoring-a-real-service-or-fixing-an-incident"></a>

### Is this monitoring a real service or fixing an incident? 🔎

The service signals and initial incident story are synthetic. The acknowledgment
and explicit action events are real records saved on the PSU server. Repeating
acknowledgment preserves the original response and one
state transition. Acknowledgment records receipt of a warning and performs no
service repair.

<a name="is-this-ready-for-production-or-tested-on-other-platforms"></a>

### Is this ready for production or tested on other platforms? 🚧

This is a **single-server community preview**. The recorded
live baseline is ICC 0.1.1 on Windows with the PSU/module **2026.3.3** pair,
PowerShell **7.6.6** and Codex CLI; 0.1.2 has offline validation only. Linux, other PSU
releases or clients, custom service identities and multiple nodes remain untested.
Use it as a learning example; assess and test any adaptation for your environment.

<a name="what-if-setup-stops-or-i-want-to-start-another-rehearsal"></a>

### What if setup stops, or I want to start another rehearsal? 🔄

Fresh installers stop on existing names, routes or installation folders; use
[Updating and recovery](docs/UPGRADE.md) to inspect and reuse an existing setup.
For another exercise, choose **New rehearsal** in the app. All viewers share
the active rehearsal, so coordinate first. Earlier exercise data is retained;
there is no automatic cleanup.

**ICC 0.1.2 targets Windows with PowerShell Universal 2026.3.3 and
Devolutions.PowerShellUniversal 2026.3.3.** The service signals are synthetic;
acknowledgment is stored on disk. This community preview uses one shared active
rehearsal on one PSU server.

![Saved-state counters, native controls and the completed runbook](docs/workflow.jpg)

Recorded ICC 0.1.1 native workflow after **Create handoff**: one saved-state
transition, one safe repeat and three completed runbook steps. Handoff completion
is specific to the browser session. This retained image is not new 0.1.2 visual evidence.

## Install

Run on the Windows server hosting PSU using **PowerShell 7.5.4 or later**.
You need the exact PSU/management-module 2026.3.3 pair, an app-capable PSU license,
an enabled **PowerShell 7** environment and an existing Administrator app token.

Extract the matching 0.1.2 release ZIP, or use the source at tag `v0.1.2`.
Open an elevated PowerShell 7
session in the package directory and keep the module folder beside the installer.
For the standard PSU Windows installation:

```powershell
$token = Read-Host 'PSU Administrator app token' -AsSecureString
.\Install-IncidentCommandCenter.ps1 -ServerUrl http://localhost:5000 -AppToken $token -ManagementModulePath 'C:\Program Files (x86)\Universal\Modules\Universal\Devolutions.PowerShellUniversal.psd1'
Remove-Variable token
```

Use your actual local origin if the port differs. The installer accepts localhost,
IPv4/IPv6 loopback or the server's machine name. It checks exact server and module
versions, keeps authentication enabled and grants access only to Administrator.
The bundled directory named `Universal` contains the current Devolutions manifest.
`-ManagementModulePath` requires an existing local absolute `.psd1` path; omit it
only when exact-version module discovery is available.

Open `/incident-command-center` and sign in as an Administrator. The first visit
creates a rehearsal. App and automation processes need access to the shared
exercise files.

Existing names, routes and installation folders stop a fresh installation.
`-WhatIf` still reads the server before skipping writes. For an occupied or partial
installation, use [Updating and recovery](docs/UPGRADE.md).

## Use the app

1. **See the signal.** Checkout latency is 820 ms against a 500 ms demo threshold.
2. **Acknowledge.** Record that an operator has seen the warning.
3. **Verify saved state.** Read the stored acknowledgment again.
4. **Repeat safely.** Preserve the first response, timestamp and one transition.
5. **Create handoff.** Summarize the situation, action, verification and next owner.

Acknowledgment does not repair a service; the warning remains visible.
Before acknowledgment, **Verify saved state** reports that no acknowledgment
exists yet and leaves persistence unverified. If prior actions reference an
acknowledgment whose file is missing, ICC stops and requests complete-backup
recovery rather than silently reopening the incident. See [recovery](docs/UPGRADE.md#missing-acknowledgment-data).
**New rehearsal** creates a separate exercise and retains previous exercise data.
All viewers share the current rehearsal. Coordinate before replacing it.
Native actions and MCP calls reject stale exercise IDs; refresh the app or Inspect
the current exercise before continuing.

## Try the MCP demo

Follow [MCP setup and usage](docs/MCP.md). The tool exposes Inspect, Acknowledge
and Handoff through PSU's MCP endpoint. PSU runs the selected PowerShell and stores
the result; the external assistant supplies the conversation. Refresh ICC after
chat actions. The native dashboard works without an AI account or external API.

PSU AI features must be enabled for MCP: **Disable AI Features** must be off.
Use an existing Administrator token through the client's local secret mechanism.
Never commit tokens or client credentials.

## Tests and scope

The following live versions describe the retained **ICC 0.1.1** baseline.
ICC 0.1.2 has been checked offline with PowerShell 7.6.6 on Windows;
its native PSU app and MCP/model workflow have not been rerun.

| Tested component | Version |
| --- | --- |
| PSU and Devolutions.PowerShellUniversal | 2026.3.3 |
| PowerShell runtime | 7.6.6 |
| Codex CLI MCP client | 0.162.0-alpha.17.2 |

PowerShell 7.5.4 is the package minimum. The offline suites use isolated state
and simulated installer commands, without PSU or credentials:

```powershell
pwsh -NoProfile -File .\tests\Test-IncidentCommandCenter.ps1
pwsh -NoProfile -File .\tests\Test-IccMcp.ps1
pwsh -NoProfile -File .\tests\Test-IccInstallers.ps1
pwsh -NoProfile -File .\tests\Test-IccWorkflow.ps1
pwsh -NoProfile -File .\tests\Test-IccStateRecovery.ps1
```

Outputs go under ignored `output/` storage. The preview has not been tested on
Linux, other PSU releases, other clients, custom service identities or multiple
nodes. It supplies fixed signals and a demo timeline, with no monitoring connector,
automatic remediation or human-attributed audit log.

## Code and data

- `PowerShellUniversal.Apps.IncidentCommandCenter/`: module, dashboard, styles and state engine.
- `Install-IncidentCommandCenter.ps1`: app installer.
- `Install-IccMcpTool.ps1` and `mcp/`: optional MCP tool installer and wrapper.
- `tests/`: offline checks.
- `docs/`: [MCP](docs/MCP.md), [architecture](docs/ARCHITECTURE.md) and [updating/recovery](docs/UPGRADE.md).

Code installs under `%ProgramData%\PowerShellUniversal\Showcases\IncidentCommandCenter\0.1.2`.
Exercise data lives separately under `%ProgramData%\PowerShellUniversal\IncidentCommandCenter`.
There is no automatic cleanup. See [architecture and removal](docs/ARCHITECTURE.md)
for shared-state behavior and deliberate removal.

## License

[Release notes and change history](RELEASE-NOTES.md).

[MIT](LICENSE). Copyright 2026 Mike Simpson. An independent community project;
PowerShell Universal and external clients retain their own licensing requirements.

*Une production des Externes de Devolutions.*
