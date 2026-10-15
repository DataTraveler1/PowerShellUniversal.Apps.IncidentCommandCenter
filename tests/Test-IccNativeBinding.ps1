#Requires -Version 7.5.4
[CmdletBinding()]
param(
    [string]$OutputDirectory=(Join-Path $PSScriptRoot ('../output/native-binding-'+[guid]::NewGuid().ToString('N'))),
    [string]$ModulePath=(Join-Path $PSScriptRoot '../PowerShellUniversal.Apps.IncidentCommandCenter/PowerShellUniversal.Apps.IncidentCommandCenter.psd1')
)
# Offline only. Real dashboard callbacks, serialized argument snapshots and local
# UI shims; fresh synthetic stores. No PSU transport, credentials or jobs.
$ErrorActionPreference='Stop'
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
$ModulePath=[IO.Path]::GetFullPath($ModulePath)
if(Test-Path -LiteralPath $OutputDirectory){throw 'Use a fresh output directory.'}
$null=New-Item -ItemType Directory -Path $OutputDirectory
$previousRoot=$env:ICC_DEMO_DATA_ROOT
$cases=[Collections.Generic.List[object]]::new()
$observations=[Collections.Generic.List[object]]::new()
$script:checks=0
function Confirm-IccBinding($Condition,[string]$Message){$script:checks++;if(-not $Condition){throw $Message}}
function Test-IccBindingCase([string]$Name,[scriptblock]$Body){
    try{& $Body;$cases.Add([pscustomobject]@{name=$Name;outcome='PASS'})}
    catch{$cases.Add([pscustomobject]@{name=$Name;outcome='FAIL';error=$_.Exception.Message;stack=$_.ScriptStackTrace})}
}
function Get-IccBindingInventory {
    (@(Get-ChildItem -LiteralPath $env:ICC_DEMO_DATA_ROOT -Recurse -File|Sort-Object FullName|ForEach-Object{
        $_.FullName+'|'+(Get-FileHash -LiteralPath $_.FullName).Hash+'|'+$_.LastWriteTimeUtc.Ticks
    })-join "`n")
}
function New-UDApp {param($Title,[scriptblock]$Content) $null=& $Content}
function New-UDStyle {param($Style,[scriptblock]$Content) $null=& $Content}
function New-UDElement {param($Tag,$Attributes,[scriptblock]$Content) $null=& $Content}
function New-UDDynamic {param($Id,[scriptblock]$Content) $null=& $Content}
function New-UDHtml {param($Markup) $global:IccBindingMarkup.Add([string]$Markup)}
function New-UDEndpoint {
    param($Id,[object[]]$ArgumentList,[scriptblock]$Endpoint)
    # PSU executes endpoint text later with ArgumentList; do not retain a closure.
    [pscustomobject]@{body=$Endpoint.ToString();arguments=@($ArgumentList|ForEach-Object{[string]$_})}
}
function New-UDButton {
    param($Id,$Text,$Variant,$Color,$ClassName,$OnClick)
    $global:IccBindingButtons[$Text]=[pscustomobject]@{id=$Id;callback=$OnClick}
}
function Show-UDToast {param($Message,$Duration) $global:IccBindingToasts.Add([string]$Message)}
function Sync-UDElement {param($Id)}
function New-UDTypography {param($Text,$Variant)}
function Show-UDModal {param([scriptblock]$Header,[scriptblock]$Content,[scriptblock]$Footer,[switch]$FullWidth,$MaxWidth) $global:IccBindingModalCount++;$null=& $Content}
function Invoke-IccBindingCallback($Callback){
    if($Callback -is [scriptblock]){$ArgumentList=@();& ([scriptblock]::Create($Callback.ToString()))}
    else{$ArgumentList=$Callback.arguments;& ([scriptblock]::Create($Callback.body))}
}
function Render-IccBindingView {
    $global:IccBindingButtons=@{}
    & (Join-Path (Split-Path -Parent $ModulePath) 'dashboard/IncidentCommandCenter.ps1')
}
$null=New-PSDrive -Name Cache -PSProvider Variable -Root ''
$null=New-PSDrive -Name Session -PSProvider Variable -Root ''
Set-Variable -Name IccShowcaseModuleRoot -Scope Global -Value (Split-Path -Parent $ModulePath)
Set-Variable -Name IccShowcaseCss -Scope Global -Value ''
$global:IccBindingToasts=[Collections.Generic.List[string]]::new()
$global:IccBindingMarkup=[Collections.Generic.List[string]]::new()
$global:IccBindingModalCount=0
try {
    Import-Module $ModulePath -Force
    foreach($button in @('Repeat acknowledgment','Verify saved state','Create handoff 📋')){
        Test-IccBindingCase ('Superseded view: '+$button) {
            $env:ICC_DEMO_DATA_ROOT=Join-Path $OutputDirectory ('stale-'+$cases.Count)
            $older=New-IccDemoExercise
            $null=Invoke-IccDemoAction -Action Acknowledge -ExerciseId $older.ExerciseId
            Render-IccBindingView
            $oldButton=$global:IccBindingButtons[$button]
            $newer=New-IccDemoExercise
            Render-IccBindingView
            # Reproduce another tab changing the shared Session value explicitly.
            Set-Variable -Name IccExerciseId -Scope Global -Value $newer.ExerciseId
            $before=Get-IccBindingInventory
            $modalBefore=$global:IccBindingModalCount
            Invoke-IccBindingCallback $oldButton.callback
            $observations.Add([pscustomobject]@{button=$button;visibleExerciseId=$older.ExerciseId;currentExerciseId=$newer.ExerciseId;message=$global:IccBindingToasts[-1];filesUnchanged=((Get-IccBindingInventory) -ceq $before);modalOpened=($global:IccBindingModalCount -gt $modalBefore)})
            Confirm-IccBinding ($global:IccBindingToasts[-1] -like '*active rehearsal changed*') 'The old request must report the changed rehearsal.'
            Confirm-IccBinding ((Get-IccBindingInventory) -ceq $before) 'The old request must preserve both stores, pointer, hashes and write times.'
            Confirm-IccBinding ($global:IccBindingModalCount -eq $modalBefore) 'A superseded handoff must not open a summary.'
            $current=Get-IccDemoExercise -ExerciseId $newer.ExerciseId
            Confirm-IccBinding ($current.State.incidentStatus -ceq 'Open' -and $current.Events.Count -eq 0) 'The fresh rehearsal must remain Open with no action events.'
            $newButtonName=if($button -ceq 'Repeat acknowledgment'){'Acknowledge incident'}else{$button}
            Confirm-IccBinding ($oldButton.id -cne $global:IccBindingButtons[$newButtonName].id) 'Buttons in different rehearsals must not reuse a component identity.'
        }
    }
    Test-IccBindingCase 'Current callbacks still verify, acknowledge, repeat and hand off' {
        $env:ICC_DEMO_DATA_ROOT=Join-Path $OutputDirectory 'current'
        $current=New-IccDemoExercise
        Render-IccBindingView
        Set-Variable -Name IccExerciseId -Scope Global -Value $current.ExerciseId
        Invoke-IccBindingCallback $global:IccBindingButtons['Verify saved state'].callback
        Confirm-IccBinding ($global:IccBindingToasts[-1] -like 'No acknowledgment*') 'An Open verification must remain truthful.'
        Invoke-IccBindingCallback $global:IccBindingButtons['Acknowledge incident'].callback
        Confirm-IccBinding ($global:IccBindingToasts[-1] -like 'Incident acknowledged*') 'Current acknowledgment must work.'
        $state=Get-IccDemoExercise -ExerciseId $current.ExerciseId
        Render-IccBindingView
        Invoke-IccBindingCallback $global:IccBindingButtons['Repeat acknowledgment'].callback
        Confirm-IccBinding ($global:IccBindingToasts[-1] -like 'Already acknowledged*') 'Current repeat must preserve the acknowledgment.'
        Invoke-IccBindingCallback $global:IccBindingButtons['Verify saved state'].callback
        Confirm-IccBinding ($global:IccBindingToasts[-1] -like '*loaded the saved acknowledgment from disk*') 'Current saved-state verification must work.'
        $modalBefore=$global:IccBindingModalCount
        Invoke-IccBindingCallback $global:IccBindingButtons['Create handoff 📋'].callback
        Confirm-IccBinding ($global:IccBindingModalCount -eq $modalBefore+1) 'Current handoff must open its summary.'
        $after=Get-IccDemoExercise -ExerciseId $current.ExerciseId
        Confirm-IccBinding ($after.State.stateSha256 -ceq $state.State.stateSha256 -and $after.State.transitionCount -eq 1) 'All callbacks must preserve the first saved response.'
    }
} finally {$env:ICC_DEMO_DATA_ROOT=$previousRoot}
$failed=@($cases|Where-Object outcome -EQ 'FAIL')
$report=[ordered]@{outcome=if($failed.Count){'FAIL'}else{'PASS'};checks=$script:checks;cases=$cases.ToArray();observations=$observations.ToArray();psuRequests=0;scope='Actual serialized native callbacks after a newer render and Session replacement, plus the current workflow; UI shims are not live PSU acceptance.'}
$report|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json')
$report|ConvertTo-Json -Depth 8
if($failed.Count){exit 1}
