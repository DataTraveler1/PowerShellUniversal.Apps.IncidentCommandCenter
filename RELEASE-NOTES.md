# Incident Command Center release notes

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
