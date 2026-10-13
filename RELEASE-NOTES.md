# Incident Command Center 0.1.1

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
