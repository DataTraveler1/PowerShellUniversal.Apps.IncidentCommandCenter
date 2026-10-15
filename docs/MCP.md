<a name="mcp-setup-and-usage"></a>

# Connect your AI service to PSU with MCP

ICC is an example of using **Model Context Protocol (MCP)** to connect an AI
service to selected PowerShell Universal tools. You ask in plain English; the
service uses its MCP client to discover and request **ICC_Demo_Incident**.
PSU runs the PowerShell on the server and returns the tool result for the reply.

The tool can inspect, acknowledge and hand off the Acme rehearsal shown in the
ICC dashboard. Refresh the dashboard after chat actions. Its native buttons
also work without an AI service.

This guide describes ICC 0.1.3. It retains the 0.1.1 tool contract and shared
data format. Isolated native HTTP MCP qualification passed; the actual packaged
app and MCP installers also passed on refreshed PSU 2026.3.3. The AI introduction
was updated after release; the v0.1.3 tag and downloads remain unchanged.

## Choose your AI service and client

You can use a commercial AI service, or an application connected to a large
language model (LLM) your organization provides. You need both an **MCP-capable
client/application** and a **model that can use tools**. The client must support remote HTTP MCP connections
and PSU app-token authentication. A model endpoint alone does not provide that
connection.

Documented MCP-capable options include
[GitHub Copilot in VS Code](https://code.visualstudio.com/docs/agent-customization/mcp-servers),
[Codex](https://learn.chatgpt.com/docs/extend/mcp) and
[Claude Code](https://code.claude.com/docs/en/mcp). **Only Codex has been tested
with ICC**; other clients and organization-provided model setups require your
own validation. Check your chosen client's documentation for its connection and
credential settings. The Codex example below reflects the client used for ICC's
dated qualification.

Your AI service supplies the model and conversation. PSU supplies the MCP
endpoint, authenticated tool access, server-side PowerShell execution and job
output. The ICC wrapper limits its operations to this rehearsal; other PSU
information or actions require separately selected and exposed tools.

## Before you connect

Install the app using the [README prerequisites and installation steps](../README.md#install),
then register the tool and configure the client below. This example uses existing
PSU Administrator access. Choose a trusted AI service and review which tools and
returned data you permit it to use.

## Register the tool

Install the ICC 0.1.3 app first. On the same PSU 2026.3.3 Windows server, use
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

The wrapper imports the installed 0.1.3 module. App and automation processes
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
account; your AI service uses the model access configured in its client.

[Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp) and
[PSU AI Tools](https://docs.devolutions.net/powershell-universal/intelligence/ai-tools)
describe the connection mechanism. On October 15, 2026 UTC (October 14 local),
one signed-in Codex CLI **0.162.0-alpha.17.2** session used native HTTP against
Windows Server 2019 / PSU and Devolutions.PowerShellUniversal **2026.3.3** /
PowerShell **7.6.6**. It discovered the full exercise ID in its first Inspect,
then acknowledged, inspected, repeated, inspected and prepared a handoff. All
six returned frames and the exact model handoff matched stored Completed PSU
job outputs and the saved record.

That run used the unchanged 0.1.3 wrapper behind an isolated adapter and retained
lab alias **ICC_012_Qualification**, with separate data and session-only client
settings. That earlier run did not test fresh installer registration or persistent project
configuration. The October 15 clean-install pass separately ran the unchanged
packaged installers and discovered/called the standard ICC_Demo_Incident tool.
Its Inspect matched the native saved response and its Completed PSU job.
It used no new model session; the earlier model results remain dated evidence. The saved-project configuration result remains the dated 0.1.1
baseline. Other clients have not been tested.

## Demonstrate the conversation

Coordinate with other viewers, then choose **New rehearsal** for a fresh take.
It changes the shared active exercise and preserves previous rehearsals.
Give your AI service this instruction:

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

If a call reports that an acknowledgment file is missing, stop and follow
[complete-backup recovery](UPGRADE.md#missing-acknowledgment-data). Do not repeat
acknowledgment to recreate the record. If an event-write failure says
acknowledgment is saved, inspect that saved response before deciding to retry.

See the [README](../README.md), [architecture](ARCHITECTURE.md) and [updating/recovery](UPGRADE.md).
