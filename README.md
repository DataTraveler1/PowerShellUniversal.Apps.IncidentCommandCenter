# Incident Command Center

A PowerShell Universal app for practicing incident response at the fictional
**Acme Inc.** See a checkout warning, acknowledge it, verify the saved response,
repeat safely and create a handoff. The optional **ICC_Demo_Incident** MCP tool
lets an external assistant use the same rehearsal.

**ICC 0.1.1 targets Windows with PowerShell Universal 2026.3.3 and
Devolutions.PowerShellUniversal 2026.3.3.** The service signals are synthetic;
acknowledgment is stored on disk. This community preview uses one shared active
rehearsal on one PSU server.

![Saved-state counters, native controls and the completed runbook](docs/workflow.jpg)

The native workflow after **Create handoff**: one saved-state transition, one
safe repeat and three completed runbook steps. Handoff completion is specific
to the browser session.

## Install

Run on the Windows server hosting PSU using **PowerShell 7.5.4 or later**.
You need the exact PSU/management-module 2026.3.3 pair, an app-capable PSU license,
an enabled **PowerShell 7** environment and an existing Administrator app token.

Extract the release ZIP or clone this repository. Open an elevated PowerShell 7
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
**New rehearsal** creates a separate exercise and retains previous exercise data.
All viewers share the current rehearsal. Coordinate before replacing it.
Native actions and MCP calls reject stale exercise IDs; refresh the app or Inspect
the current exercise before continuing.

## Optional MCP

Follow [MCP setup and usage](docs/MCP.md). The tool exposes Inspect, Acknowledge
and Handoff through PSU's MCP endpoint. PSU runs the selected PowerShell and stores
the result; the external assistant supplies the conversation. Refresh ICC after
chat actions. The native dashboard works without an AI account or external API.

PSU AI features must be enabled for MCP: **Disable AI Features** must be off.
Use an existing Administrator token through the client's local secret mechanism.
Never commit tokens or client credentials.

## Tests and scope

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

Code installs under `%ProgramData%\PowerShellUniversal\Showcases\IncidentCommandCenter\0.1.1`.
Exercise data lives separately under `%ProgramData%\PowerShellUniversal\IncidentCommandCenter`.
There is no automatic cleanup. See [architecture and removal](docs/ARCHITECTURE.md)
for shared-state behavior and deliberate removal.

## License

[MIT](LICENSE). Copyright 2026 Mike Simpson. An independent community project;
PowerShell Universal and external clients retain their own licensing requirements.

*Une production des Externes de Devolutions.*
