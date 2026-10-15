# Incident Command Center release notes

## Documentation update after 0.1.3 — October 15, 2026

- Lead with connecting an AI service to PSU through MCP, using ICC as a working
  example of selected tool calls, server-side execution, saved state and handoff.
- Explain commercial AI services and organization-provided LLMs through compatible
  MCP clients and models that can use tools. Link Copilot in VS Code, Codex and
  Claude Code documentation while retaining Codex as the only ICC-tested client.
- Use **AI service** terminology in the public introduction and connection guide.
  Preserve the earlier FAQ link anchor for existing links.
- Align the repository description and release introduction with that purpose.

This is a main-branch documentation and public-presentation update. Runtime,
installers, tests, version, the v0.1.3 tag and all release assets are unchanged.
The tagged source and downloadable ZIP retain the original reviewed documentation;
use the main-branch README and MCP guide for the newer AI introduction. The dated
0.1.3 validation scope below has not been extended by these editorial changes.

## 0.1.3 — Windows / PSU 2026.3.3, October 15, 2026

- Bind native Acknowledge, Verify and Handoff requests to the rehearsal shown
  with the button. Give these controls exercise-specific identities.
- Keep the server current-ID guard so a superseded tab is rejected before it
  can acknowledge, verify or prepare a handoff for another rehearsal.
- Add regression coverage that renders a new view, changes Session data and
  invokes the older view's three actual callbacks.
- Align code paths, installers and module metadata to ICC 0.1.3.

Qualification on October 15, 2026 UTC (October 14 local): 338 offline checks
passed, plus 47 recovery/concurrency checks on the Windows server. The actual
native workflow and same-browser stale Acknowledge/Verify/Handoff checks passed;
both stores retained their bytes and write times after the rejected clicks.
One signed-in Codex session made six native HTTP MCP calls, with exact returned,
stored-job and model fact/handoff agreement. Original 0.1.1 resources and retained
0.1.2 code/data were preserved.

The isolated app/script/tool reused their lab IDs and names with new 0.1.3 code
and data roots. On October 15, the actual unchanged packaged app and MCP installers passed on
refreshed PSU 2026.3.3. Its empty ICC names/code/data paths were verified after
residual folders were preserved in a dated backup. Standard native use and one
direct MCP Inspect passed, with matching saved state and Completed job output.
No new model session, identity/main-service change or deletion occurred.
The 71 simulated installer scenarios supplement that real installation test.

Published as a regular release for the documented single-server learning-example
scope. Other platforms/clients, custom service identities and multiple nodes remain
untested. Earlier releases and their frozen assets remain available.


## 0.1.2 — Community preview, October 14, 2026

Corrections from the independent 0.1.1 adversarial review:

- Serialize state/timeline readers with action writers to prevent Windows file
  sharing collisions. Return each action's snapshot before releasing its lock.
- Refuse to recreate a missing acknowledgment when retained actions show one
  existed. Require the record again under the state lock, preserve the affected
  store and explain complete-backup recovery.
- Make Verify and Open-read timeline messages distinguish an absent
  acknowledgment from an actual persisted-state read. Keep the verification
  badge unset until a saved acknowledgment is independently read.
- Explain that acknowledgment is saved if a later timeline write fails.
- Add focused offline regression checks, including concurrent readers/writers,
  missing-file refusal and recovery, and the actual Verify callback with UI shims.
- Align installers, wrapper, module metadata and code paths to ICC 0.1.2 while
  retaining the existing shared data format and PSU/module 2026.3.3 target.

Validation is offline on Windows with PowerShell 7.6.6. No new live PSU, MCP/model,
installation or visual acceptance is claimed. The published 0.1.1 tag, assets,
dated evidence and retained workflow image remain unchanged. See [README](README.md)
for preview scope and [recovery](docs/UPGRADE.md) for existing installations.

## 0.1.1 — Published community preview

Community preview for Windows with PowerShell Universal and
Devolutions.PowerShellUniversal 2026.3.3.

- Native incident dashboard with synthetic Acme service signals.
- Durable acknowledgment, explicit saved-state verification and safe repetition.
- Handoff from the saved record and browser-session runbook completion.
- Shared active rehearsal with stale-action guards for native and MCP operations.
- Optional ICC_Demo_Incident MCP tool exposing Inspect, Acknowledge and Handoff.
- Exact-version installers supporting local IPv4/IPv6 origins and an explicit management-manifest path.
- Offline tests and installation, MCP, architecture and recovery guides.

PowerShell 7.5.4 or later is required. The tested runtime is 7.6.6; the tested MCP
client is Codex CLI 0.162.0-alpha.17.2. The preview uses one server and one shared
rehearsal. It does not monitor or repair services. Other clients/platforms,
custom identities and multiple nodes are untested.

MIT license. See the [README](README.md) for installation and usage.
