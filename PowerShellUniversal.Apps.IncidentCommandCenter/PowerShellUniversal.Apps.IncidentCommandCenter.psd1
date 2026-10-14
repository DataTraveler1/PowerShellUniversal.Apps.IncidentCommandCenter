@{
    RootModule = 'PowerShellUniversal.Apps.IncidentCommandCenter.psm1'
    ModuleVersion = '0.1.2'
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
            ReleaseNotes = 'ICC 0.1.2 community preview for Windows PSU 2026.3.3. Coordinates timeline readers/writers, refuses missing acknowledgment data and corrects initial verification wording. Offline validation only; see RELEASE-NOTES.md and README.md.'
        }
    }
}
