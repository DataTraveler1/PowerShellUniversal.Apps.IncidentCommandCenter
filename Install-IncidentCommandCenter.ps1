#Requires -Version 7.5.4
<#
.SYNOPSIS
Installs the preview on the Windows machine running PowerShell Universal 2026.3.3.
.DESCRIPTION
Creates one Administrator-only app and copies this package's module to ProgramData.
Run locally on the PSU server. Existing apps or installed files are never replaced.
Rehearsal data is retained separately from the versioned application code.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [uri]$ServerUrl = 'http://localhost:5000',
    [Parameter(Mandatory)][securestring]$AppToken,
    [string]$ManagementModulePath
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This preview installer targets Windows.' }
if ($ServerUrl.Scheme -notin @('http','https') -or $ServerUrl.UserInfo -or $ServerUrl.Query -or $ServerUrl.Fragment -or $ServerUrl.AbsolutePath -ne '/') {
    throw 'ServerUrl must be an HTTP or HTTPS origin without credentials, a path, or query.'
}
if ($ServerUrl.DnsSafeHost -notin @('localhost','127.0.0.1','::1',[Environment]::MachineName)) {
    throw 'Run this installer on the PSU server and use its localhost URL or machine name.'
}
if ($PSBoundParameters.ContainsKey('ManagementModulePath')) {
    if ([string]::IsNullOrWhiteSpace($ManagementModulePath) -or
        -not [IO.Path]::IsPathFullyQualified($ManagementModulePath) -or
        $ManagementModulePath.StartsWith('\\') -or [IO.Path]::GetExtension($ManagementModulePath) -ine '.psd1') {
        throw 'ManagementModulePath must be a local absolute .psd1 manifest path.'
    }
    if (-not (Test-Path -LiteralPath $ManagementModulePath -PathType Leaf)) { throw 'The management module manifest does not exist.' }
    $managementModule = Import-Module -Name $ManagementModulePath -PassThru -ErrorAction Stop
} else {
    $managementModule = Import-Module Devolutions.PowerShellUniversal -RequiredVersion 2026.3.3 -PassThru -ErrorAction Stop
}
if ($managementModule.Name -cne 'Devolutions.PowerShellUniversal' -or $managementModule.Version -ne [version]'2026.3.3') {
    throw 'This installer requires Devolutions.PowerShellUniversal 2026.3.3. The loaded module does not match.'
}
$moduleName = 'PowerShellUniversal.Apps.IncidentCommandCenter'
$source = Join-Path $PSScriptRoot $moduleName
$targetRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/Showcases/IncidentCommandCenter/0.1.2'
$targetModule = Join-Path $targetRoot $moduleName
$manifest = Join-Path $targetModule ($moduleName + '.psd1')
$origin = $ServerUrl.AbsoluteUri.TrimEnd('/')
$tokenText = [pscredential]::new('PSU', $AppToken).GetNetworkCredential().Password
try {
    $version = Invoke-RestMethod -Uri ($origin + '/api/v1/version') -Headers @{ Authorization = 'Bearer ' + $tokenText } -TimeoutSec 15
    if ([string]$version -notmatch '^2026\.3\.3(?:\.0)?$') { throw 'This preview targets PSU 2026.3.3. Installation stopped on a different version.' }
    $apps = @(Get-PSUApp -ComputerName $origin -AppToken $tokenText)
    if (@($apps | Where-Object { $_.Name -ieq 'Incident Command Center' -or $_.BaseUrl.TrimEnd('/') -ieq '/incident-command-center' }).Count) {
        throw 'The app name or route already exists. Open that app; this installer will not overwrite it.'
    }
    if (Test-Path -LiteralPath $targetRoot) { throw 'The versioned installation folder already exists. Inspect it before attempting another install.' }
    if (-not (Test-Path -LiteralPath (Join-Path $source ($moduleName + '.psd1')))) { throw 'Keep this installer beside the complete module folder.' }
    if ($PSCmdlet.ShouldProcess($origin, 'Copy Incident Command Center 0.1.2 and create its Administrator-only app')) {
        $null = New-Item -Path $targetRoot -ItemType Directory
        Copy-Item -LiteralPath $source -Destination $targetRoot -Recurse
        $escapedManifest = $manifest.Replace("'", "''")
        $content = [scriptblock]::Create("Import-Module '$escapedManifest' -Force; New-UDIncidentCommandCenterApp")
        $app = New-PSUApp -Name 'Incident Command Center' -BaseUrl '/incident-command-center' -Content $content -Environment 'PowerShell 7' -Authenticated -Role @('Administrator') -Description 'Demo incident response rehearsal. Acknowledge, verify, repeat safely, and hand off.' -ComputerName $origin -AppToken $tokenText
        [pscustomobject]@{
            AppId = $app.Id
            AppUrl = $origin + '/incident-command-center'
            ModulePath = $targetModule
            StatePath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/IncidentCommandCenter'
            Access = 'Authenticated users in the Administrator role'
        }
    }
} finally { $tokenText = $null }
