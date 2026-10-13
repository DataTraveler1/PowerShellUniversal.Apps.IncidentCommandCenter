@{
    RootModule = 'PowerShellUniversal.Apps.IncidentCommandCenter.psm1'
    ModuleVersion = '0.1.1'
    GUID = 'a36ca703-647d-4d6e-8cd4-92f8cb946102'
    Author = 'Mike Simpson'
    Copyright = '(c) 2026 Mike Simpson. MIT License.'
    Description = 'A rehearsal-ready incident response desk for PowerShell Universal. Demo signals, durable acknowledgment, safe repeats, and a useful handoff.'
    PowerShellVersion = '7.5.4'
    FunctionsToExport = @('New-UDIncidentCommandCenterApp','New-IccDemoExercise','Get-IccDemoExercise','Invoke-IccDemoAction','Get-IccDemoHandoff','Get-IccDemoView','Invoke-IccDemoToolOperation')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShellUniversal','app','incident','operations','demo')
            ProjectUri = 'https://github.com/DataTraveler1/PowerShellUniversal.Apps.IncidentCommandCenter'
            LicenseUri = 'https://github.com/DataTraveler1/PowerShellUniversal.Apps.IncidentCommandCenter/blob/main/LICENSE'
            ReleaseNotes = 'ICC 0.1.1 for Windows PowerShell Universal 2026.3.3. Durable acknowledgment, saved-state verification, safe repetition, native handoff and an optional shared-rehearsal MCP tool. See README.md for installation and usage.'
        }
    }
}
