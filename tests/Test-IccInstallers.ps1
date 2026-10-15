#Requires -Version 7.5.4
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot ('../output/installer-test-' + [guid]::NewGuid().ToString('N'))))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'These installer checks require Windows; all installation and PSU operations are simulated.' }
$package = Split-Path -Parent $PSScriptRoot
$moduleName = 'PowerShellUniversal.Apps.IncidentCommandCenter'
$sourceModule = Join-Path $package $moduleName
$targetRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/Showcases/IncidentCommandCenter/0.1.3'
$installedManifest = Join-Path $targetRoot ($moduleName + '/' + $moduleName + '.psd1')
$wrapperPath = Join-Path $package 'mcp/Invoke-IccDemoTool.ps1'
$wrapperSource = Get-Content -LiteralPath $wrapperPath -Raw
$checks = 0
$cases = [Collections.Generic.List[object]]::new()
function Confirm-IccInstaller($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}

# Only pure helper cmdlets are available. Module autoloading is disabled.
# Every installation, file-read and PSU command below is a function backed by
# in-memory fixtures. A new runspace is used for each actual installer invocation.
$mockDispatch = @'
[CmdletBinding()]
param([string]$Name, [Collections.IDictionary]$Parameters)
$ctx = $global:IccSimulation
$recorded = @{}
foreach ($key in $Parameters.Keys) {
    if ($key -notin @('AppToken','Headers')) { $recorded[$key] = $Parameters[$key] }
}
$ctx.Calls.Add([pscustomobject]@{Name=$Name; Parameters=$recorded})
$cfg = $ctx.Config
switch ($Name) {
    'Import-Module' {
        if ($Parameters.Name -eq 'Devolutions.PowerShellUniversal' -or $Parameters.Name -eq $ctx.ManagementManifest) {
            if ($cfg.ModuleMissing) { throw 'Fixture: Devolutions.PowerShellUniversal is unavailable.' }
            if ($Parameters.PassThru) { [pscustomobject]@{Name=$cfg.ModuleName; Version=[version]$cfg.ModuleVersion} }
        } elseif ($Parameters.Name -eq $ctx.InstalledManifest) {
            if ($Parameters.PassThru) { [pscustomobject]@{Name=$ctx.ModuleName; Version=[version]$cfg.LoadedIccVersion} }
        } else { throw 'Unexpected module import in offline simulation.' }
    }
    'Test-Path' {
        if ($Parameters.LiteralPath -eq $ctx.ManagementManifest) {
            if ($Parameters.PathType -cne 'Leaf') { throw 'Explicit management manifest must be checked as a file.' }
            return -not $cfg.ManagementPathMissing
        }
        if ($Parameters.LiteralPath -eq $ctx.TargetRoot) { return [bool]$cfg.FolderExists }
        if ($Parameters.LiteralPath -eq $ctx.InstalledManifest) { return -not $cfg.InstalledMissing }
        if ($Parameters.LiteralPath -eq $ctx.SourceManifest) { return -not $cfg.SourceMissing }
        throw 'Unexpected path in offline simulation.'
    }
    'Import-PowerShellDataFile' {
        if ($Parameters.LiteralPath -ne $ctx.InstalledManifest) { throw 'Unexpected manifest read.' }
        @{ModuleVersion=$cfg.IccManifestVersion}
    }
    'Get-Content' {
        if ($Parameters.LiteralPath -ne $ctx.WrapperPath -or -not $Parameters.Raw) { throw 'Unexpected source read.' }
        $ctx.WrapperSource
    }
    'Invoke-RestMethod' {
        if ([string]$Parameters.Uri -cne ($ctx.Origin + '/api/v1/version')) { throw 'Unexpected simulated HTTP request.' }
        $cfg.ServerVersion
    }
    'Get-PSUApp' { $cfg.Apps }
    'Get-PSUScript' { $cfg.Scripts }
    'Get-PSUAiTool' { $cfg.Tools }
    'New-Item' {
        if ($Parameters.Path -ne $ctx.TargetRoot -or $Parameters.ItemType -ne 'Directory') { throw 'Unexpected simulated directory write.' }
        $ctx.Folders.Add($Parameters.Path)
        [pscustomobject]@{FullName=$Parameters.Path}
    }
    'Copy-Item' {
        if ($Parameters.LiteralPath -ne $ctx.SourceModule -or $Parameters.Destination -ne $ctx.TargetRoot -or -not $Parameters.Recurse) { throw 'Unexpected simulated copy.' }
        if ($cfg.CopyFails) { throw 'Fixture: module copy failed.' }
        $ctx.Copied = $true
    }
    'New-PSUApp' {
        if ($cfg.AppCreationFails) { throw 'Fixture: app creation failed.' }
        $ctx.AppCreated = $true
        [pscustomobject]@{Id=901}
    }
    'New-PSUScript' {
        $ctx.ScriptCreated = $true
        [pscustomobject]@{Id=902; FullPath='icc-demo-mcp.ps1'}
    }
    'New-PSUAiTool' {
        if ($cfg.ToolCreationFails) { throw 'Fixture: tool registration failed.' }
        $ctx.ToolCreated = $true
        [pscustomobject]@{Id=903; Name=$Parameters.Name}
    }
    default { throw ('Unexpected simulated command: ' + $Name) }
}
'@
$mockParameters = [ordered]@{
    'Import-Module' = '[Parameter(Position=0)]$Name,[version]$RequiredVersion,[switch]$PassThru,[switch]$Force'
    'Test-Path' = '[string]$LiteralPath,[string]$PathType'
    'Import-PowerShellDataFile' = '[string]$LiteralPath'
    'Get-Content' = '[string]$LiteralPath,[switch]$Raw'
    'Invoke-RestMethod' = '[uri]$Uri,[hashtable]$Headers,[int]$TimeoutSec'
    'Get-PSUApp' = '[string]$ComputerName,[string]$AppToken'
    'Get-PSUScript' = '[string]$ComputerName,[string]$AppToken'
    'Get-PSUAiTool' = '[string]$ComputerName,[string]$AppToken'
    'New-Item' = '[string]$Path,[string]$ItemType'
    'Copy-Item' = '[string]$LiteralPath,[string]$Destination,[switch]$Recurse'
    'New-PSUApp' = '[string]$Name,[string]$BaseUrl,[scriptblock]$Content,[string]$Environment,[switch]$Authenticated,[string[]]$Role,[string]$Description,[string]$ComputerName,[string]$AppToken'
    'New-PSUScript' = '[string]$Name,[scriptblock]$ScriptBlock,[string]$Environment,[string[]]$Role,[string]$Description,[string]$ComputerName,[string]$AppToken'
    'New-PSUAiTool' = '[string]$Name,[string]$ScriptFullPath,[string]$Description,[switch]$Authenticated,[string[]]$Role,[switch]$Mcp,[string]$Environment,[int]$DefaultMaxWaitTimeoutSeconds,[string]$ComputerName,[string]$AppToken'
}
$pureCommands = @(foreach ($name in @('Join-Path','Where-Object','Get-Command','Write-Information')) { Get-Command $name -CommandType Cmdlet })
$writeCommands = @('New-Item','Copy-Item','New-PSUApp','New-PSUScript','New-PSUAiTool')
function Invoke-IccInstallerCase([string]$Name, [ValidateSet('App','Mcp')][string]$Kind, [hashtable]$Overrides = @{}, [switch]$WhatIf, [uri]$ServerUrl = 'http://localhost:5000', [string]$ManagementModulePath) {
    $config = @{
        ServerVersion='2026.3.3'; ModuleName='Devolutions.PowerShellUniversal'; ModuleVersion='2026.3.3'
        IccManifestVersion='0.1.3'; LoadedIccVersion='0.1.3'; Apps=@(); Scripts=@(); Tools=@()
    }
    foreach ($key in $Overrides.Keys) { $config[$key] = $Overrides[$key] }
    $context = [pscustomobject]@{
        Config=$config; Calls=[Collections.Generic.List[object]]::new(); Folders=[Collections.Generic.List[string]]::new(); Origin=$ServerUrl.AbsoluteUri.TrimEnd('/')
        ModuleName=$moduleName; SourceModule=$sourceModule; SourceManifest=(Join-Path $sourceModule ($moduleName + '.psd1'))
        ManagementManifest='C:\Program Files (x86)\Universal\Modules\Universal\Devolutions.PowerShellUniversal.psd1'
        TargetRoot=$targetRoot; InstalledManifest=$installedManifest; WrapperPath=$wrapperPath; WrapperSource=$wrapperSource
        Copied=$false; AppCreated=$false; ScriptCreated=$false; ToolCreated=$false
    }
    $initialState = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $initialState.Commands.Clear()
    $installer = if ($Kind -eq 'App') { 'Install-IncidentCommandCenter.ps1' } else { 'Install-IccMcpTool.ps1' }
    $installerPath = Join-Path $package $installer
    $initialState.Commands.Add([Management.Automation.Runspaces.SessionStateScriptEntry]::new($installerPath))
    foreach ($command in $pureCommands) {
        $initialState.Commands.Add([Management.Automation.Runspaces.SessionStateCmdletEntry]::new($command.Name, $command.ImplementingType, $null))
    }
    $initialState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('PSModuleAutoLoadingPreference', 'None', 'Offline check boundary'))
    $initialState.Variables.Add([Management.Automation.Runspaces.SessionStateVariableEntry]::new('IccSimulation', $context, 'In-memory fixtures'))
    $initialState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-IccMock', $mockDispatch))
    foreach ($commandName in $mockParameters.Keys) {
        $definition = '[CmdletBinding()] param(' + $mockParameters[$commandName] + ') Invoke-IccMock -Name ''' + $commandName + ''' -Parameters $PSBoundParameters'
        $initialState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new($commandName, $definition))
    }
    if (-not $config.BridgeMissing) {
        $initialState.Commands.Add([Management.Automation.Runspaces.SessionStateFunctionEntry]::new('Invoke-IccDemoToolOperation', 'throw "The installer must not invoke the bridge."'))
    }
    $runspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($initialState)
    $shell = [Management.Automation.PowerShell]::Create()
    $errorMessage = $null
    $output = @()
    try {
        $runspace.Open()
        $shell.Runspace = $runspace
        $null = $shell.AddCommand($installerPath).AddParameter('AppToken', (ConvertTo-SecureString 'synthetic-offline-fixture' -AsPlainText -Force)).AddParameter('ServerUrl', $ServerUrl).AddParameter('Confirm', $false)
        if ($WhatIf) { $null = $shell.AddParameter('WhatIf', $true) }
        if ($PSBoundParameters.ContainsKey('ManagementModulePath')) { $null = $shell.AddParameter('ManagementModulePath', $ManagementModulePath) }
        try { $output = @($shell.Invoke()) } catch { $errorMessage = $_.Exception.Message }
        if ($shell.Streams.Error.Count) { $errorMessage = $shell.Streams.Error[0].Exception.Message }
    } finally {
        $shell.Dispose()
        $runspace.Dispose()
    }
    $writes = @($context.Calls | Where-Object Name -In $writeCommands)
    $cases.Add([pscustomobject]@{name=$Name; installer=$Kind; expectedOutcome='Pending'; error=$errorMessage; simulatedCommands=@($context.Calls.Name); simulatedWriteAttempts=$writes.Count; realPsuRequests=0})
    [pscustomobject]@{Name=$Name; Error=$errorMessage; Output=$output; Context=$context; Writes=$writes; Report=$cases[-1]}
}
function Confirm-IccRefused($Case, [string]$MessagePattern) {
    Confirm-IccInstaller ($Case.Error -match $MessagePattern) ($Case.Name + ': expected refusal, got ' + $Case.Error)
    Confirm-IccInstaller ($Case.Writes.Count -eq 0) ($Case.Name + ': refusal must precede writes')
    $Case.Report.expectedOutcome = 'Refused'
}
function Get-IccCall($Case, [string]$Name) {
    @($Case.Context.Calls | Where-Object Name -EQ $Name)
}

$manifestData = Import-PowerShellDataFile -LiteralPath (Join-Path $sourceModule ($moduleName + '.psd1'))
Confirm-IccInstaller ($manifestData.ModuleVersion -ceq '0.1.3') 'Package manifest must be 0.1.3.'
foreach ($kind in @('App','Mcp')) {
    foreach ($version in @('2026.3.3','2026.3.3.0')) {
        $case = Invoke-IccInstallerCase "$kind accepts $version" $kind @{ServerVersion=$version}
        Confirm-IccInstaller (-not $case.Error) ($case.Name + ': ' + $case.Error)
        $moduleImport = (Get-IccCall $case 'Import-Module')[0].Parameters
        Confirm-IccInstaller ($moduleImport.Name -ceq 'Devolutions.PowerShellUniversal' -and $moduleImport.RequiredVersion -eq [version]'2026.3.3' -and $moduleImport.PassThru) ($case.Name + ': exact management import')
        if ($kind -eq 'App') {
            $app = (Get-IccCall $case 'New-PSUApp')[0].Parameters
            Confirm-IccInstaller ($app.Authenticated -and $app.Role.Count -eq 1 -and $app.Role[0] -ceq 'Administrator' -and $app.Environment -ceq 'PowerShell 7') 'App access and environment must remain bounded.'
            Confirm-IccInstaller ($app.Name -ceq 'Incident Command Center' -and $app.BaseUrl -ceq '/incident-command-center') 'App identity and route must remain stable.'
            Confirm-IccInstaller ($app.Content.ToString().Contains($installedManifest) -and $case.Output[0].ModulePath -eq (Join-Path $targetRoot $moduleName)) 'App must import 0.1.3 from its copied module.'
            Confirm-IccInstaller ($case.Context.Copied -and $case.Output[0].StatePath -eq (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PowerShellUniversal/IncidentCommandCenter')) 'Code update must retain the separate state root.'
        } else {
            $scriptCall = (Get-IccCall $case 'New-PSUScript')[0].Parameters
            $tool = (Get-IccCall $case 'New-PSUAiTool')[0].Parameters
            Confirm-IccInstaller ($scriptCall.Name -ceq 'icc-demo-mcp.ps1' -and $scriptCall.ScriptBlock.ToString().Contains('IncidentCommandCenter/0.1.3/')) 'Registered wrapper must use the 0.1.3 code path.'
            Confirm-IccInstaller ($scriptCall.Role.Count -eq 1 -and $scriptCall.Role[0] -ceq 'Administrator' -and $scriptCall.Environment -ceq 'PowerShell 7') 'Script access and environment must remain bounded.'
            Confirm-IccInstaller ($tool.Name -ceq 'ICC_Demo_Incident' -and $tool.ScriptFullPath -ceq 'icc-demo-mcp.ps1' -and $tool.Authenticated -and $tool.Mcp -and $tool.Role.Count -eq 1 -and $tool.Role[0] -ceq 'Administrator') 'Tool must retain its authenticated Administrator MCP contract.'
            Confirm-IccInstaller ($tool.Environment -ceq 'PowerShell 7' -and $tool.DefaultMaxWaitTimeoutSeconds -eq 30 -and $case.Output[0].McpUrl -ceq 'http://localhost:5000/api/v1/mcp') 'Tool runtime and output route must remain unchanged.'
        }
        $case.Report.expectedOutcome = 'Installed'
    }
    foreach ($version in @('2026.3.0','2026.3.1','2026.3.4','2026.3.30','2026.3.3-preview','')) {
        $case = Invoke-IccInstallerCase "$kind refuses server [$version]" $kind @{ServerVersion=$version}
        Confirm-IccRefused $case 'targets PSU 2026.3.3'
        Confirm-IccInstaller ((Get-IccCall $case 'Get-PSUApp').Count -eq 0 -and (Get-IccCall $case 'Get-PSUScript').Count -eq 0 -and (Get-IccCall $case 'Get-PSUAiTool').Count -eq 0) 'Version refusal must precede resource reads.'
    }
    foreach ($fixture in @(@{ModuleMissing=$true}, @{ModuleVersion='2026.3.1'}, @{ModuleName='Universal'})) {
        $case = Invoke-IccInstallerCase "$kind refuses management module $($fixture.Keys)" $kind $fixture
        Confirm-IccRefused $case 'Devolutions.PowerShellUniversal'
        Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 0) 'Missing or mismatched module must precede server reads.'
    }
    foreach ($origin in @('http://localhost:5000/path','https://remote.example.test','http://fixture@localhost:5000')) {
        $case = Invoke-IccInstallerCase "$kind refuses origin $origin" $kind -ServerUrl $origin
        Confirm-IccRefused $case 'origin|Run this installer'
        Confirm-IccInstaller ($case.Context.Calls.Count -eq 0) 'Invalid origins must precede imports and server reads.'
    }
    $case = Invoke-IccInstallerCase "$kind WhatIf" $kind -WhatIf
    Confirm-IccInstaller (-not $case.Error -and $case.Writes.Count -eq 0 -and $case.Output.Count -eq 0) 'WhatIf must skip all writes and creation receipts.'
    Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 1) 'WhatIf still performs the simulated version read.'
    $case.Report.expectedOutcome = 'WhatIf'
    $explicitPath='C:\Program Files (x86)\Universal\Modules\Universal\Devolutions.PowerShellUniversal.psd1'
    $case = Invoke-IccInstallerCase "$kind explicit bundled manifest" $kind -ManagementModulePath $explicitPath
    Confirm-IccInstaller (-not $case.Error) ($case.Name + ': ' + $case.Error)
    $explicitImport=(Get-IccCall $case 'Import-Module')[0].Parameters
    Confirm-IccInstaller ($explicitImport.Name -ceq $explicitPath -and $explicitImport.PassThru -and -not $explicitImport.ContainsKey('RequiredVersion')) 'Explicit manifest must avoid short-name rediscovery.'
    Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 1) 'Exact explicit module permits the version read.'
    Confirm-IccInstaller ($case.Writes.Count -eq $(if ($kind -eq 'App') {3} else {2})) 'Explicit-path install retains the same scoped writes.'
    $case.Report.expectedOutcome='Installed'
    foreach ($badPath in @('', 'Modules\Devolutions.PowerShellUniversal.psd1', 'C:\module.dll', '\\server\share\Devolutions.PowerShellUniversal.psd1')) {
        $case=Invoke-IccInstallerCase "$kind invalid manifest path [$badPath]" $kind -ManagementModulePath $badPath
        Confirm-IccRefused $case 'local absolute .psd1'
        Confirm-IccInstaller ((Get-IccCall $case 'Import-Module').Count -eq 0 -and (Get-IccCall $case 'Invoke-RestMethod').Count -eq 0) 'Invalid paths must precede imports and requests.'
    }
    $case=Invoke-IccInstallerCase "$kind missing explicit manifest" $kind @{ManagementPathMissing=$true} -ManagementModulePath $explicitPath
    Confirm-IccRefused $case 'manifest does not exist'
    Confirm-IccInstaller ((Get-IccCall $case 'Import-Module').Count -eq 0 -and (Get-IccCall $case 'Invoke-RestMethod').Count -eq 0) 'Missing explicit manifest must precede import and requests.'
    foreach ($fixture in @(@{ModuleMissing=$true}, @{ModuleVersion='2026.3.1'}, @{ModuleName='Universal'})) {
        $case=Invoke-IccInstallerCase "$kind explicit module refusal $($fixture.Keys)" $kind $fixture -ManagementModulePath $explicitPath
        Confirm-IccRefused $case 'Devolutions.PowerShellUniversal'
        Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 0) 'Explicit import still checks name/version before requests.'
    }
    $case=Invoke-IccInstallerCase "$kind explicit manifest WhatIf" $kind -ManagementModulePath $explicitPath -WhatIf
    Confirm-IccInstaller (-not $case.Error -and $case.Writes.Count -eq 0 -and $case.Output.Count -eq 0) 'Explicit-path WhatIf creates no resources.'
    Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 1) 'Explicit-path WhatIf still reads the server version.'
    $case.Report.expectedOutcome='WhatIf'
    foreach ($localOrigin in @('http://[::1]:5000','http://127.0.0.1:5000',('http://' + [Environment]::MachineName + ':5000'))) {
        $case = Invoke-IccInstallerCase "$kind accepts local origin $localOrigin" $kind -ServerUrl $localOrigin
        Confirm-IccInstaller (-not $case.Error) ($case.Name + ': ' + $case.Error)
        Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 1) 'Accepted local origins must reach the simulated version boundary.'
        $created = (Get-IccCall $case $(if ($kind -eq 'App') {'New-PSUApp'} else {'New-PSUAiTool'}))[0].Parameters
        Confirm-IccInstaller ($created.ComputerName -ceq ([uri]$localOrigin).AbsoluteUri.TrimEnd('/')) 'Accepted local origin must be preserved for management calls.'
        $case.Report.expectedOutcome='Installed'
    }
}
foreach ($appFixture in @(
    [pscustomobject]@{Name='incident command center';BaseUrl='/elsewhere'},
    [pscustomobject]@{Name='Another app';BaseUrl='/INCIDENT-COMMAND-CENTER/'}
)) {
    Confirm-IccRefused (Invoke-IccInstallerCase "App refuses occupied resource $($appFixture.Name)" App @{Apps=@($appFixture)}) 'name or route already exists'
}
Confirm-IccRefused (Invoke-IccInstallerCase 'App refuses existing folder' App @{FolderExists=$true}) 'folder already exists'
Confirm-IccRefused (Invoke-IccInstallerCase 'App refuses incomplete source' App @{SourceMissing=$true}) 'complete module folder'
foreach ($fixture in @(@{Scripts=@([pscustomobject]@{Name='ICC-DEMO-MCP.PS1'})}, @{Tools=@([pscustomobject]@{Name='icc_demo_incident'})})) {
    Confirm-IccRefused (Invoke-IccInstallerCase 'Mcp refuses existing resource' Mcp $fixture) 'script or tool already exists'
}
foreach ($fixture in @(@{InstalledMissing=$true}, @{IccManifestVersion='0.1.0'}, @{LoadedIccVersion='0.1.0'}, @{IccManifestVersion='0.1.1'}, @{LoadedIccVersion='0.1.1'}, @{BridgeMissing=$true})) {
    $case = Invoke-IccInstallerCase "Mcp refuses installed package $($fixture.Keys)" Mcp $fixture
    Confirm-IccRefused $case 'Install the ICC app|manifest must be version 0.1.3|loaded ICC module must be version 0.1.3|predates the chat bridge'
    Confirm-IccInstaller ((Get-IccCall $case 'Invoke-RestMethod').Count -eq 0) 'Installed-package refusal must precede server reads.'
}
foreach ($fixture in @(@{CopyFails=$true}, @{AppCreationFails=$true})) {
    $case = Invoke-IccInstallerCase "App retains partial installation $($fixture.Keys)" App $fixture
    Confirm-IccInstaller ($case.Error -match 'Fixture:.*failed' -and $case.Context.Folders.Count -eq 1) 'An app failure must retain its created directory.'
    Confirm-IccInstaller (-not $case.Context.AppCreated -and ($case.Context.Copied -eq [bool]$fixture.AppCreationFails)) 'Partial app state must reflect where installation failed.'
    $case.Report.expectedOutcome = 'Partial retained'
}
$case = Invoke-IccInstallerCase 'Mcp retains script on failed tool registration' Mcp @{ToolCreationFails=$true}
Confirm-IccInstaller ($case.Error -match 'tool registration failed' -and $case.Context.ScriptCreated -and -not $case.Context.ToolCreated) 'Tool failure must retain the created script.'
Confirm-IccInstaller ($case.Writes.Count -eq 2) 'A partial MCP install must attempt script creation and tool registration only.'
$case.Report.expectedOutcome = 'Partial retained'
Confirm-IccInstaller (@($cases | Where-Object expectedOutcome -EQ 'Pending').Count -eq 0) 'Every scenario must have an asserted outcome.'

$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$report = [ordered]@{
    outcome='PASS'; checks=$checks; scenarios=$cases.Count; atUtc=[datetimeoffset]::UtcNow.ToString('o'); psuRequests=0
    scope='Actual installers in isolated runspaces; simulated imports, HTTP, resources and ProgramData. No live validation.'
    pureCmdlets=@($pureCommands.Name); simulatedCommands=@($mockParameters.Keys); cases=$cases.ToArray()
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json') -Encoding utf8
[pscustomobject]@{outcome=$report.outcome;checks=$checks;scenarios=$cases.Count;psuRequests=0;outputDirectory=[IO.Path]::GetFullPath($OutputDirectory)} | ConvertTo-Json
