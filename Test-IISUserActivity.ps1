#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$collector = Join-Path $PSScriptRoot 'Get-IISUserActivity.ps1'
$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($collector, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors.Message -join '; ') }

$temp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ('IISBusyTests-' + [Guid]::NewGuid().ToString('N')))
$passed = 0

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -ne $Expected) { throw "$Label : expected '$Expected', got '$Actual'." }
}

function Invoke-Collector([hashtable]$Extra) {
    $parent = Join-Path $temp.FullName ([Guid]::NewGuid().ToString('N'))
    $arguments = @{
        StartUtc = '2026-10-27T08:30:00Z'; EndUtc = '2026-10-27T09:00:00Z'
        NodeName = 'TEST-NODE'; OutputDirectory = $parent
    }
    foreach ($key in $Extra.Keys) { $arguments[$key] = $Extra[$key] }
    & $collector @arguments | Out-Null
    $runs = @(Get-ChildItem -LiteralPath $parent -Directory)
    Assert-Equal $runs.Count 1 'One unique run directory'
    $runs[0].FullName
}

function Read-Json([string]$Directory, [string]$Name) {
    Get-Content -LiteralPath (Join-Path $Directory $Name) -Raw | ConvertFrom-Json
}

function Expect-Failure([hashtable]$Extra, [string]$Pattern) {
    $parent = Join-Path $temp.FullName ([Guid]::NewGuid().ToString('N'))
    $arguments = @{
        StartUtc = '2026-10-27T08:30:00Z'; EndUtc = '2026-10-27T09:00:00Z'
        NodeName = 'TEST-NODE'; OutputDirectory = $parent
    }
    foreach ($key in $Extra.Keys) { $arguments[$key] = $Extra[$key] }
    $failure = $null
    try { & $collector @arguments | Out-Null } catch { $failure = $_ }
    if ($null -eq $failure -or $failure.Exception.Message -notlike $Pattern) {
        throw "Expected failure '$Pattern', got '$failure'."
    }
    if (Test-Path -LiteralPath $parent) {
        $runs = @(Get-ChildItem -LiteralPath $parent -Directory)
        $record = Read-Json $runs[0].FullName 'collection-failure.json'
        Assert-Equal $record.Status 'Failed_PartialFilesMustNotBeTreatedAsComplete' 'Failure marker'
    }
}

try {
    $a = 'a' * 64
    $b = 'b' * 64
    $c = 'c' * 64
    $d = 'd' * 64
    $e = 'e' * 64
    $log = Join-Path $temp.FullName 'iis.log'
    @(
        '#Software: Microsoft Internet Information Services 8.0'
        '#Fields: date time cs-username sc-status sc-substatus sc-win32-status time-taken app-session-hash'
        "2026-10-27 08:29:59 DOMAIN\alice 200 0 0 1 $a"
        "2026-10-27 08:30:00 DOMAIN\alice 200 0 0 100 $a"
        "2026-10-27 08:30:20 DOMAIN\alice 503 2 0 300 $b"
        "2026-10-27 08:30:30 DOMAIN\bob 200 0 0 200 $c"
        '2026-10-27 08:30:40 - 503 3 0 400 -'
        '#Fields: time date sc-status cs-username time-taken sc-win32-status sc-substatus app-session-hash'
        "08:31:00 2026-10-27 200 domain\ALICE 500 0 0 $a"
        "09:00:00 2026-10-27 200 DOMAIN\alice 10 0 0 $a"
        'incomplete final line'
    ) | Set-Content -LiteralPath $log -Encoding ASCII
    $http = Join-Path $temp.FullName 'httperr.log'
    @(
        '#Fields: date time s-status s-reason'
        '2026-10-27 08:30:01 503 QueueFull'
        '2026-10-27 08:31:01 503 QueueFull'
        '2026-10-27 08:32:01 503 ConnLimit'
    ) | Set-Content -LiteralPath $http -Encoding ASCII
    $run = Invoke-Collector @{ LogPath = @($log, $log); HttpErrPath = $http; SessionHashField = 'app-session-hash'; UserName = 'DOMAIN\alice' }
    $summary = Read-Json $run 'summary.json'
    Assert-Equal $summary.RequestsInLogs 5 'Inclusive start / exclusive end, file deduplication'
    Assert-Equal $summary.RequestsWithoutIdentity 1 'Anonymous identity is unknown'
    $users = @(Import-Csv -LiteralPath (Join-Path $run 'users-observed.csv'))
    Assert-Equal $users.Count 1 'User filter'
    Assert-Equal $users[0].CompletedRequests 3 'Case-insensitive user grouping'
    Assert-Equal $users[0].DistinctSessionHashesObserved 2 'Historical session deduplication'
    Assert-Equal $users[0].RequestsWithSessionField 3 'Hash coverage'
    $minutes = @(Import-Csv -LiteralPath (Join-Path $run 'requests-by-minute.csv'))
    Assert-Equal $minutes.Count 2 'Reordered header and minute buckets'
    Assert-Equal $minutes[0].CompletedRequests 4 'User filter does not filter node metrics'
    Assert-Equal $minutes[0].AverageTimeTakenMs 250 'Measured duration average'
    Assert-Equal $minutes[0].MaxTimeTakenMs 400 'Measured maximum duration'
    Assert-Equal $minutes[0].Errors503 2 '503 minute count'
    Assert-Equal $minutes[0].DistinctIdentifiedUsersObserved 2 'Distinct known identities'
    $reasons = @(Import-Csv -LiteralPath (Join-Path $run 'httperr-summary.csv'))
    Assert-Equal ($reasons | Where-Object Reason -eq 'QueueFull').Requests 2 'HTTPERR QueueFull aggregation'
    $coverage = @(Read-Json $run 'coverage.json')
    Assert-Equal $coverage[0].MalformedLines 1 'Malformed line is visible'
    $notices = @(Read-Json $run 'warnings.json')
    if (-not ($notices -like '*malformed*')) { throw 'Malformed line warning is missing.' }
    $passed++
    Write-Host 'PASS: IIS/HTTPERR boundaries, headers, deduplication, user filter, unknown identity and metrics'

    $inventory = Join-Path $temp.FullName 'sessions.csv'
    @(
        'UserId,SessionKeyHash,LastSeenUtc,ExpiresUtc,IsRevoked'
        "DOMAIN\alice,$a,2026-10-27T08:58:00Z,2026-10-27T09:28:00Z,false"
        "DOMAIN\alice,$b,2026-10-27T14:29:00+05:30,2026-10-27T14:59:00+05:30,false"
        "DOMAIN\alice,$c,2026-10-27T08:00:00Z,2026-10-27T09:00:00Z,false"
        "DOMAIN\alice,$d,2026-10-27T08:58:00Z,2026-10-27T09:28:00Z,true"
        "DOMAIN\bob,$e,2026-10-27T09:01:00Z,2026-10-27T09:28:00Z,false"
    ) | Set-Content -LiteralPath $inventory -Encoding ASCII
    $run = Invoke-Collector @{ SessionInventoryPath = $inventory }
    $sessions = @(Import-Csv -LiteralPath (Join-Path $run 'application-sessions.csv'))
    Assert-Equal ($sessions | Where-Object User -eq 'DOMAIN\alice').ActiveSessions 2 'Unexpired non-revoked sessions'
    Assert-Equal ($sessions | Where-Object User -eq 'DOMAIN\bob').ActiveSessions 0 'Future activity is not active as of earlier snapshot'
    $passed++
    Write-Host 'PASS: authoritative inventory expiry, revocation, offset conversion and as-of boundary'

    $simple = Join-Path $temp.FullName 'minimal.log'
    @(
        '#Fields: date time sc-status'
        '2026-10-27 08:30:00 200'
    ) | Set-Content -LiteralPath $simple -Encoding ASCII
    $run = Invoke-Collector @{ LogPath = $simple; SessionHashField = 'app-session-hash' }
    Assert-Equal (Read-Json $run 'summary.json').RequestsWithoutIdentity 1 'Missing identity field'
    Assert-Equal @(Import-Csv -LiteralPath (Join-Path $run 'users-observed.csv')).Count 0 'No invented users'
    $minute = @(Import-Csv -LiteralPath (Join-Path $run 'requests-by-minute.csv'))[0]
    Assert-Equal $minute.AverageTimeTakenMs '' 'Missing timing is blank, not zero'
    $passed++
    Write-Host 'PASS: absent user and timing fields remain unknown'

    $unsafe = Join-Path $temp.FullName 'unsafe.log'
    @(
        '#Fields: date time cs-username sc-status'
        '2026-10-27 08:30:00 =formula 200'
    ) | Set-Content -LiteralPath $unsafe -Encoding ASCII
    $run = Invoke-Collector @{ LogPath = $unsafe; SessionHashField = 'missing-hash' }
    $user = @(Import-Csv -LiteralPath (Join-Path $run 'users-observed.csv'))[0]
    Assert-Equal $user.User "'=formula" 'Spreadsheet-safe identity'
    Assert-Equal $user.DistinctSessionHashesObserved '' 'Missing hash field stays unknown'
    $passed++
    Write-Host 'PASS: CSV formula escaping and missing session-hash field'

    Expect-Failure @{ LogPath = $log; StartUtc = '2026-10-27T09:00:00Z' } '*StartUtc must be earlier*'
    Expect-Failure @{ LogPath = (Join-Path $temp.FullName 'not-found.log') } '*does not exist*'
    Expect-Failure @{ LogPath = $log; SessionHashField = 'cs(Cookie)' } '*never cookies*'
    $passed++
    Write-Host 'PASS: invalid parameters and missing files fail explicitly'

    $invalidLog = Join-Path $temp.FullName 'no-header.log'
    '2026-10-27 08:30:00 200' | Set-Content -LiteralPath $invalidLog -Encoding ASCII
    Expect-Failure @{ LogPath = $invalidLog } '*No #Fields header*'
    $badHash = Join-Path $temp.FullName 'raw-session.log'
    @(
        '#Fields: date time cs-username sc-status app-session-hash'
        '2026-10-27 08:30:00 alice 200 raw-session-token'
    ) | Set-Content -LiteralPath $badHash -Encoding ASCII
    Expect-Failure @{ LogPath = $badHash; SessionHashField = 'app-session-hash' } '*64-hex*'
    $passed++
    Write-Host 'PASS: headerless logs and raw session identifiers are rejected'

    $duplicate = Join-Path $temp.FullName 'duplicate-sessions.csv'
    @(
        'UserId,SessionKeyHash,LastSeenUtc,ExpiresUtc,IsRevoked'
        "alice,$a,2026-10-27T08:58:00Z,2026-10-27T09:28:00Z,false"
        "alice,$a,2026-10-27T08:58:00Z,2026-10-27T09:28:00Z,false"
    ) | Set-Content -LiteralPath $duplicate -Encoding ASCII
    Expect-Failure @{ SessionInventoryPath = $duplicate } '*one row per globally unique session hash*'
    $noZone = Join-Path $temp.FullName 'no-zone.csv'
    @(
        'UserId,SessionKeyHash,LastSeenUtc,ExpiresUtc,IsRevoked'
        "alice,$a,2026-10-27T08:58:00,2026-10-27T09:28:00Z,false"
    ) | Set-Content -LiteralPath $noZone -Encoding ASCII
    Expect-Failure @{ SessionInventoryPath = $noZone } '*explicit timezone*'
    $passed++
    Write-Host 'PASS: duplicate registry sessions and ambiguous timestamps fail explicitly'
    Write-Host "All $passed offline test groups passed. Live IIS still requires validation on an actual IIS node."
} finally {
    Remove-Item -LiteralPath $temp.FullName -Recurse -Force
}
