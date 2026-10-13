# MCP setup and usage

Put an external MCP-capable assistant beside the ICC dashboard. The assistant
uses **ICC_Demo_Incident** to inspect, acknowledge and hand off the same Acme
rehearsal shown in the app. PSU runs the PowerShell and stores the acknowledgment.
Refresh the dashboard after chat actions. The app also works with its native buttons.

## Register the tool

Install the ICC 0.1.1 app first. On the same PSU 2026.3.3 Windows server, use
PowerShell 7.5.4 or later and Devolutions.PowerShellUniversal 2026.3.3:

```powershell
$token = Read-Host 'PSU Administrator app token' -AsSecureString
.\Install-IccMcpTool.ps1 -ServerUrl http://localhost:5000 -AppToken $token -ManagementModulePath 'C:\Program Files (x86)\Universal\Modules\Universal\Devolutions.PowerShellUniversal.psd1'
Remove-Variable token
```

Use the actual local origin and matching manifest path for your installation.
This creates script **icc-demo-mcp.ps1** and authenticated Administrator-only
MCP tool **ICC_Demo_Incident**. Existing names stop the installer. A registration
failure retains any created script so you can inspect it. `-WhatIf` skips
creation but still reads the server.

If those resources already exist, follow [Upgrade and recovery](UPGRADE.md).
Reuse their existing definitions instead of running the fresh installer again.

The wrapper imports the installed 0.1.1 module. App and automation processes
must use the same shared data root and have access to its files. The default
ProgramData location supplies that store; different `ICC_DEMO_DATA_ROOT` values
would select different stores.

## Configure the client

PSU AI features must be enabled. Under **Settings gear > Automation**, ensure
**Disable AI Features** is off. Disabling AI removes the MCP endpoint and makes
`/api/v1/mcp` return 404, even if the script and tool definitions are retained.

Use your PSU origin followed by `/api/v1/mcp`, with an existing Administrator
app token supplied through the client's supported local secret mechanism.
Restrict its enabled tools to **ICC_Demo_Incident** for the demonstration.
Never put a real token in source control, command arguments or chat messages.

For Codex, a generic example in a trusted project's `.codex/config.toml` is:

```toml
[mcp_servers.icc_demo]
url = "https://psu.example.test/api/v1/mcp"
bearer_token_env_var = "PSU_ICC_MCP_TOKEN"
enabled_tools = ["ICC_Demo_Incident"]
startup_timeout_sec = 20
tool_timeout_sec = 90
```

Replace the example URL with your instance. Make the token environment variable
available to the client before it starts, using your normal local credential
handling. Codex loads project configuration only for trusted projects. Approve
the intended demo actions when the client asks. The app itself needs no model
account; the external assistant uses its existing model access.

[Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp) and
[PSU AI Tools](https://docs.devolutions.net/powershell-universal/intelligence/ai-tools)
describe the connection mechanism. Codex CLI native HTTP and one saved project
configuration are the tested client route on the Windows/PSU 2026.3.3 pair, using
Codex CLI **0.162.0-alpha.17.2** and PowerShell **7.6.6**.
Other clients have not been tested with this preview.

## Demonstrate the conversation

Coordinate with other viewers, then choose **New rehearsal** for a fresh take.
It changes the shared active exercise and preserves previous rehearsals.
Give the assistant this instruction:

> Use ICC_Demo_Incident for all incident facts and actions. Inspect first, retain
> the full exerciseId and send it with later calls. Stop on tool failures. An
> acknowledgment records receipt of the alert; it does not repair a service.

Ask:

1. **What needs attention at Acme?** Inspect should report checkout latency of
   820 ms against 500 ms, Warning and Open for the fresh exercise.
2. **Acknowledge it, then read it again.** Acknowledge followed by Inspect should
   show Acknowledged, one transition and the saved response. Refresh ICC.
3. **Acknowledge it again, then verify the saved response once more.** The repeat
   should return AlreadyAcknowledged and preserve the original timestamp and
   one transition. The following Inspect verifies the acknowledgment again.
4. **Prepare a handoff from those saved facts.** Handoff should include the
   situation, actual response, verification, next owner and next action.

The fresh six-call sequence is Inspect → Acknowledge → Inspect → Acknowledge →
Inspect → Handoff. Its initial Open read records an action but cannot verify
an acknowledgment that does not exist yet. The two later reads verify it.
An already acknowledged rehearsal returns AlreadyAcknowledged for both acknowledgment calls.

## Tool behavior

| Action | Effect |
| --- | --- |
| Inspect | Reads the active exercise and records a Read event. |
| Acknowledge | Saves receipt once; requires the exact current exercise ID. |
| Handoff | Returns a summary from saved facts; requires that same ID. |

Each response has a unique callId. PSU runs the wrapper as an automation job;
compare the returned callId and facts with the completed job output when checking
the result. A stale exercise ID is rejected after a new rehearsal. Inspect the
current exercise and confirm the operator's intent before acting on a different one.
The tool has no arbitrary-command, service-remediation, messaging or new-rehearsal operation.

See the [README](../README.md), [architecture](ARCHITECTURE.md) and [updating/recovery](UPGRADE.md).
