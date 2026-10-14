#Requires -Version 7.5.4
<#
.SYNOPSIS
Registers the optional ICC demo MCP tool after the app is installed.
.DESCRIPTION
Run on the PSU 2026.3.3 Windows server. Creates one script and one authenticated,
Administrator-only AI Tool. Existing names are never replaced. Retains resources
if a later step fails so the operator can inspect them before continuing.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param([uri]$ServerUrl = 'http://localhost:5000', [Parameter(Mandatory)][securestring]$AppToken, [string]$ManagementModulePath)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This installer targets Windows.' }
if ($ServerUrl.Scheme -notin @('http','https') -or $ServerUrl.UserInfo -or $ServerUrl.Query -or $ServerUrl.Fragment -or $ServerUrl.AbsolutePath -ne '/' -or
    $ServerUrl.DnsSafeHost -notin @('localhost','127.0.0.1','::1',[Environment]::MachineName)) {
    throw 'Run on the PSU server using its localhost origin or machine name, without a path or credentials.'
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
$manifest = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('PowerShellUniversal/Showcases/IncidentCommandCenter/0.1.2/' + $moduleName + '/' + $moduleName + '.psd1')
if (-not (Test-Path -LiteralPath $manifest)) { throw 'Install the ICC app from this package first.' }
$installedManifest = Import-PowerShellDataFile -LiteralPath $manifest
if ([version]$installedManifest.ModuleVersion -ne [version]'0.1.2') { throw 'The installed ICC manifest must be version 0.1.2 before registering this tool.' }
$installedModule = Import-Module $manifest -Force -PassThru
if ($installedModule.Name -cne $moduleName -or $installedModule.Version -ne [version]'0.1.2') { throw 'The loaded ICC module must be version 0.1.2 before registering this tool.' }
if (-not (Get-Command Invoke-IccDemoToolOperation -ErrorAction SilentlyContinue)) { throw 'The installed app module predates the chat bridge. Update that module before registering this tool.' }
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'mcp/Invoke-IccDemoTool.ps1') -Raw
$origin = $ServerUrl.AbsoluteUri.TrimEnd('/')
$tokenText = [pscredential]::new('PSU', $AppToken).GetNetworkCredential().Password
try {
    $version = Invoke-RestMethod -Uri ($origin + '/api/v1/version') -Headers @{Authorization = 'Bearer ' + $tokenText} -TimeoutSec 15
    if ([string]$version -notmatch '^2026\.3\.3(?:\.0)?$') { throw 'This preview targets PSU 2026.3.3.' }
    $scripts = @(Get-PSUScript -ComputerName $origin -AppToken $tokenText)
    $tools = @(Get-PSUAiTool -ComputerName $origin -AppToken $tokenText)
    if (@($scripts | Where-Object Name -IEQ 'icc-demo-mcp.ps1').Count -or @($tools | Where-Object Name -IEQ 'ICC_Demo_Incident').Count) {
        throw 'The ICC script or tool already exists. Inspect and reuse it; this installer does not overwrite or duplicate it.'
    }
    if ($PSCmdlet.ShouldProcess($origin, 'Create icc-demo-mcp.ps1 and the Administrator-only ICC_Demo_Incident MCP tool')) {
        $script = New-PSUScript -Name 'icc-demo-mcp.ps1' -ScriptBlock ([scriptblock]::Create($source)) -Environment 'PowerShell 7' -Role @('Administrator') -Description 'Acme ICC current rehearsal: inspect, acknowledge and hand off.' -ComputerName $origin -AppToken $tokenText
        Write-Information ('Created script ID ' + $script.Id + '. Retained if tool registration fails.') -InformationAction Continue
        $tool = New-PSUAiTool -Name 'ICC_Demo_Incident' -ScriptFullPath $script.FullPath -Description 'Work with Acme Inc. current ICC demo. Inspect first for facts and exerciseId. Acknowledge requires that exact ID and records receipt once; repeats preserve it. Handoff returns saved facts. Warning remains; no service repair.' -Authenticated -Role @('Administrator') -Mcp -Environment 'PowerShell 7' -DefaultMaxWaitTimeoutSeconds 30 -ComputerName $origin -AppToken $tokenText
        [pscustomobject]@{ScriptId=$script.Id; ToolId=$tool.Id; ToolName=$tool.Name; McpUrl=$origin + '/api/v1/mcp'; Access='Authenticated Administrator'; State='Same active rehearsal as ICC app'}
    }
} finally { $tokenText = $null }
