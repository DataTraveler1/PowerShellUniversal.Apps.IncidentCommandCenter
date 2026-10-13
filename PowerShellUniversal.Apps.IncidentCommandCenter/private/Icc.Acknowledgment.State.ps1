# Self-contained state engine, embedded verbatim in the deployed W4 script.
# No I/O occurs when this file is dot-sourced. Root is an internal test seam;
# the deployed script fixes it beneath CommonApplicationData, never a tool input.
function Invoke-IccW4State {
    param([string]$Root,[string]$Action,[string]$Nonce,[string]$AcknowledgmentId='')
    $ErrorActionPreference='Stop'
    if ($Action -cnotin @('Read','Acknowledge') -or $Nonce -cnotmatch '\A[a-f0-9]{32}\z' -or
        ($Action -ceq 'Acknowledge' -and $AcknowledgmentId -cnotmatch '\A[a-f0-9]{32}\z') -or
        ($Action -ceq 'Read' -and $AcknowledgmentId -cne '')) {throw 'InvalidW4Input'}
    $rootPath=[IO.Path]::GetFullPath($Root)
    [void][IO.Directory]::CreateDirectory($rootPath)
    $path=Join-Path $rootPath 'DEMO-INC-001.json'
    $lockPath=Join-Path $rootPath 'DEMO-INC-001.lock'
    $lock=$null
    $wait=[Diagnostics.Stopwatch]::StartNew()
    while ($null -eq $lock) {
        try {$lock=[IO.FileStream]::new($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {
            if ($wait.Elapsed.TotalSeconds -ge 5) {throw 'W4StateBusy'}
            Start-Sleep -Milliseconds 25
        }
    }
    try {
        $state=$null
        $bytes=$null
        if ([IO.File]::Exists($path)) {
            if ([IO.FileInfo]::new($path).Length -gt 4096) {throw 'InvalidW4State'}
            $bytes=[IO.File]::ReadAllBytes($path)
            $json=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
            $doc=[Text.Json.JsonDocument]::Parse($json)
            try {
                if ($doc.RootElement.ValueKind -ne [Text.Json.JsonValueKind]::Object) {throw 'InvalidW4State'}
                $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($property in $doc.RootElement.EnumerateObject()) {
                    if (-not $names.Add($property.Name)) {throw 'InvalidW4State'}
                }
            } finally {$doc.Dispose()}
            $state=ConvertFrom-Json -InputObject $json -DateKind String
            $expectedFields=@('schemaVersion','kind','incidentId','status','revision','acknowledgmentId','acknowledgedAtUtc','transitionCount')
            if ((@($state.PSObject.Properties.Name | Sort-Object) -join '|') -cne (($expectedFields | Sort-Object) -join '|')) {throw 'InvalidW4State'}
            foreach ($field in @('schemaVersion','revision','transitionCount')) {
                if (($state.$field -isnot [long] -and $state.$field -isnot [int]) -or $state.$field -ne 1) {throw 'InvalidW4State'}
            }
            foreach ($field in @('kind','incidentId','status','acknowledgmentId','acknowledgedAtUtc')) {
                if ($state.$field -isnot [string]) {throw 'InvalidW4State'}
            }
            $timestamp=[datetimeoffset]::MinValue
            if ($state.kind -cne 'PSUMCP-2026.3.0-ICC-W4-STATE' -or $state.incidentId -cne 'DEMO-INC-001' -or
                $state.status -cne 'Acknowledged' -or $state.acknowledgmentId -isnot [string] -or
                $state.acknowledgmentId -cnotmatch '\A[a-f0-9]{32}\z' -or $state.acknowledgedAtUtc -isnot [string] -or
                -not [datetimeoffset]::TryParseExact($state.acknowledgedAtUtc,'o',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$timestamp) -or
                $timestamp.Offset -ne [timespan]::Zero) {throw 'InvalidW4State'}
        }
        $disposition='Read'
        if ($Action -ceq 'Acknowledge') {
            if ($null -ne $state) {$disposition='AlreadyAcknowledged'}
            else {
                $state=[pscustomobject][ordered]@{
                    schemaVersion=1;kind='PSUMCP-2026.3.0-ICC-W4-STATE';incidentId='DEMO-INC-001'
                    status='Acknowledged';revision=1;acknowledgmentId=$AcknowledgmentId
                    acknowledgedAtUtc=[datetimeoffset]::UtcNow.ToString('o');transitionCount=1
                }
                $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($state | ConvertTo-Json -Compress))
                $pending=Join-Path $rootPath ('pending-'+[guid]::NewGuid().ToString('N')+'.json')
                $stream=[IO.FileStream]::new($pending,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
                try {$stream.Write($bytes);$stream.Flush($true)} finally {$stream.Dispose()}
                # Same-volume, non-overwriting publication while holding the lock.
                # A crash leaves either the old state or a complete new state. Any
                # uncommitted pending file is inert; no reset/recovery write occurs.
                [IO.File]::Move($pending,$path,$false)
                $disposition='Acknowledged'
            }
        }
        [pscustomobject][ordered]@{
            schemaVersion=1;kind='PSUMCP-2026.3.0-ICC-W4';nonce=$Nonce;synthetic=$true
            incidentId='DEMO-INC-001';service='Demo Checkout API';severity='Warning'
            operation=$Action;disposition=$disposition
            incidentStatus=if ($null -eq $state) {'Open'} else {'Acknowledged'}
            revision=if ($null -eq $state) {0} else {1}
            transitionCount=if ($null -eq $state) {0} else {1}
            acknowledgmentId=if ($null -eq $state) {''} else {$state.acknowledgmentId}
            acknowledgedAtUtc=if ($null -eq $state) {''} else {$state.acknowledgedAtUtc}
            stateSha256=if ($null -eq $bytes) {''} else {[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))}
        }
    } finally {$lock.Dispose()}
}
