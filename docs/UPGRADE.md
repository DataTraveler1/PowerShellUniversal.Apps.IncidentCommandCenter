# Updating and recovery

Use this procedure to update an existing ICC installation or recover resources
after an interrupted installation. The Windows server must already run PSU and
Devolutions.PowerShellUniversal 2026.3.3. This updates ICC code, not PSU itself.

The fresh installers deliberately stop at occupied app names, routes, scripts,
tools and installation folders. Rerunning them is not an upgrade or repair.

## Preserve before changing code

1. Select the exact instance. Record the ICC app ID, route, environment,
   authentication and roles. Record any ICC script/tool IDs, paths, environments,
   roles, authentication, MCP setting and default wait timeout.
2. Save the existing definitions through your normal PSU configuration backup.
   Preserve the installed ICC code and the separate
   `%ProgramData%\PowerShellUniversal\IncidentCommandCenter` data directory in a
   private backup outside the public package.
3. Coordinate with viewers, disconnect the demo MCP client and confirm no ICC
   job is running. Stop only the ICC app; keep the main PSU service running.

Keep `current.json`, exercise folders, acknowledgments, timelines and older
versioned code. Do not create a new rehearsal merely to upgrade.

## Install reviewed files and reuse the app

Verify the intended release ZIP against its matching distribution checksums.
Copy its complete module folder to:

```text
%ProgramData%\PowerShellUniversal\Showcases\IncidentCommandCenter\0.1.1\PowerShellUniversal.Apps.IncidentCommandCenter
```

If that folder already exists, preserve its complete before-copy and compare it
with the payload manifest. Replace only reviewed ICC code while the app is
stopped. Leave the shared exercise-data directory intact. Use the actual
CommonApplicationData root if your machine differs from standard ProgramData.

Edit the existing app to use this content:

```powershell
$manifest = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/Showcases/IncidentCommandCenter/0.1.1/PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1'
Import-Module $manifest -Force
New-UDIncidentCommandCenterApp
```

Keep the existing app ID, `/incident-command-center`, authentication, sole
Administrator role and **PowerShell 7** environment.

For an existing MCP installation, copy the release's `mcp/Invoke-IccDemoTool.ps1`
content into the existing **icc-demo-mcp.ps1** script. Keep its ID/path,
Administrator role and PowerShell 7 environment. Keep **ICC_Demo_Incident**
pointing to that script, authenticated, Administrator-only, MCP-enabled,
in PowerShell 7, with a 30-second default wait. Do not create duplicates.

Start the ICC app and reload the dashboard. Confirm the expected version and
saved rehearsal before reconnecting the client.

## Verify without resetting

- Compare the acknowledgment bytes/hash and timestamp with the private before-copy.
- **Create handoff** reads saved state, creates no action event or transition,
  and marks the third step complete in that browser session.
- Optional MCP **Handoff** should agree with the dashboard. It creates a PSU
  job but adds no demo action event.
- **Verify saved state**, MCP **Inspect** and repeated acknowledgment add events.
  Run them only when intended and account for those expected additions.

Native controls reject a displayed rehearsal that is no longer current.
Refresh an older dashboard before continuing.

## Continue a retained partial installation

| Existing state | Deliberate continuation |
| --- | --- |
| Code folder exists, no app | Preserve and complete the reviewed files, then create one authenticated Administrator app using the content above. |
| App exists with older/incomplete code | Stop that app, preserve its code/definition, apply reviewed files and restart the same app. |
| Script exists, tool registration failed | Verify the existing script against the release wrapper, then create or repair one tool pointing to it. Keep its script ID/path. |
| Both script and tool exist | Verify/update their existing definitions and skip the fresh MCP installer. |
| Names or paths have unexpected ownership | Resolve ownership before copying code or changing definitions. |

PSU AI features must be enabled for MCP. Use an existing Administrator token
through the client's supported secret mechanism; no new identity, role or token
is required.

## Roll back ICC code

Disconnect the client, confirm no ICC job is running and stop only the ICC app.
Restore its preserved code and app/script/tool definitions. Restart that app and
verify the saved rehearsal. Leave exercise data and the PSU version unchanged.
This is an ICC code rollback, not a PSU downgrade.

See the [README](../README.md), [MCP guide](MCP.md) and
[architecture](ARCHITECTURE.md).
