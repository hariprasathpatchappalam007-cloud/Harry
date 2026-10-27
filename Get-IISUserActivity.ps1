#requires -Version 5.1
<#
.SYNOPSIS
Read-only IIS incident collection and per-user activity/session analysis.
.DESCRIPTION
IIS W3C logs measure completed requests, not current login sessions or concurrency.
Authoritative session counts require a complete application-owned session snapshot.
No IIS settings are changed. Output can contain user identifiers: protect the folder.
.EXAMPLE
.\Get-IISUserActivity.ps1 -LogPath 'D:\Logs\W3SVC1\u_ex261027.log' -UserName 'DOMAIN\alice'
.EXAMPLE
.\Get-IISUserActivity.ps1 -CollectLiveIIS -SiteName 'My Site' -OutputDirectory 'D:\Restricted\IIS'
.EXAMPLE
.\Get-IISUserActivity.ps1 -SessionInventoryPath 'D:\Restricted\sessions.csv' -EndUtc '2026-10-27T09:00:00Z'
#>
[CmdletBinding()]
param(
    [string[]]$LogPath,
    [string[]]$HttpErrPath,
    [string]$SessionInventoryPath,
    [string]$UserName,
    [string]$UserField = 'cs-username',
    [string]$SessionHashField,
    [DateTimeOffset]$StartUtc = [DateTimeOffset]::UtcNow.AddMinutes(-30),
    [DateTimeOffset]$EndUtc = [DateTimeOffset]::UtcNow,
    [string]$NodeName = $env:COMPUTERNAME,
    [string]$OutputDirectory = (Join-Path $PWD 'IIS-Diagnostics'),
    [switch]$CollectLiveIIS,
    [string]$SiteName,
    [ValidateRange(1, 120)][int]$Samples = 12,
    [ValidateRange(1, 60)][int]$IntervalSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$start = $StartUtc.ToUniversalTime()
$end = $EndUtc.ToUniversalTime()
if ($start -ge $end) { throw 'StartUtc must be earlier than EndUtc. Use timestamps with Z or an explicit UTC offset.' }
if (-not $CollectLiveIIS -and -not $LogPath -and -not $HttpErrPath -and -not $SessionInventoryPath) {
    throw 'Supply LogPath, HttpErrPath, SessionInventoryPath, or CollectLiveIIS.'
}
if ($CollectLiveIIS -and [string]::IsNullOrWhiteSpace($SiteName)) {
    throw 'SiteName is required with CollectLiveIIS. Use the IIS site name, not a DNS hostname.'
}
if ([string]::IsNullOrWhiteSpace($NodeName)) { throw 'NodeName must not be empty.' }
if ($SessionHashField -and $SessionHashField -match '(?i)cookie|authorization') {
    throw 'Use a dedicated pseudonymous session-hash field, never cookies or authorization headers.'
}

$runName = '{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
$output = New-Item -ItemType Directory -Path (Join-Path $OutputDirectory $runName)
$warnings = [Collections.Generic.List[string]]::new()
$coverage = [Collections.Generic.List[object]]::new()

function Add-CollectionWarning([string]$Message) {
    $warnings.Add($Message)
    Write-Warning $Message
}

function Save-Json([string]$Name, $Value) {
    ConvertTo-Json -InputObject $Value -Depth 8 | Set-Content -LiteralPath (Join-Path $output.FullName $Name) -Encoding UTF8
}

function Save-Csv([string]$Name, [object[]]$Rows, [string[]]$Columns) {
    $target = Join-Path $output.FullName $Name
    if ($Rows.Count -eq 0) {
        ('"' + ($Columns -join '","') + '"') | Set-Content -LiteralPath $target -Encoding UTF8
    } else {
        # Prevent spreadsheet formula evaluation of user-controlled identifiers.
        $Rows | Select-Object $Columns | ForEach-Object {
            $row = $_
            foreach ($property in $row.PSObject.Properties) {
                if ($property.Value -is [string] -and $property.Value -match '^[\s]*[=+@-]') {
                    $property.Value = "'" + $property.Value
                }
            }
            $row
        } | Export-Csv -LiteralPath $target -NoTypeInformation -Encoding UTF8
    }
}

function Resolve-LogFiles([string[]]$Paths) {
    $seen = @{}
    foreach ($pattern in $Paths) {
        $files = @(Get-Item -Path $pattern -ErrorAction Stop)
        if ($files.Count -eq 0) { throw "No files matched: $pattern" }
        foreach ($file in $files) {
            if ($file.PSIsContainer) { throw "Supply log files or a file wildcard, not a directory: $($file.FullName)" }
            if (-not $seen.ContainsKey($file.FullName)) {
                $seen[$file.FullName] = $true
                $file
            }
        }
    }
}

function Read-W3C([IO.FileInfo]$File, [string[]]$Required, [scriptblock]$Consume) {
    $fields = @()
    $missing = @{}
    $lines = 0
    $malformed = 0
    $matched = 0
    $stream = [IO.File]::Open($File.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.StreamReader]::new($stream)
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            $lines++
            if ($line.StartsWith('#Fields:')) {
                $fields = @($line.Substring(8).Trim() -split '\s+')
                foreach ($name in $Required) {
                    if ($fields -notcontains $name) { throw "Missing required W3C field '$name' in $($File.FullName):$lines" }
                }
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
            if ($fields.Count -eq 0) { throw "No #Fields header before data in $($File.FullName):$lines" }
            $parts = @($line.Trim() -split '\s+')
            if ($parts.Count -ne $fields.Count) { $malformed++; continue }
            $record = @{}
            for ($i = 0; $i -lt $fields.Count; $i++) { $record[$fields[$i]] = $parts[$i] }
            $timestamp = [DateTimeOffset]::MinValue
            $valid = [DateTimeOffset]::TryParseExact(
                "$($record['date']) $($record['time'])", 'yyyy-MM-dd HH:mm:ss', $culture,
                [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$timestamp)
            if (-not $valid) { $malformed++; continue }
            if ($timestamp -lt $start -or $timestamp -ge $end) { continue }
            $matched++
            & $Consume $record $timestamp $missing
        }
        if ($fields.Count -eq 0) { throw "No #Fields header found in $($File.FullName)" }
    } finally {
        $reader.Dispose()
    }
    if ($malformed -gt 0) {
        Add-CollectionWarning "$($File.Name): skipped $malformed malformed/incomplete lines; analysis is partial."
    }
    foreach ($name in $missing.Keys) {
        Add-CollectionWarning "$($File.Name): '$name' missing in one or more matching records; that metric is unavailable there."
    }
    $coverage.Add([pscustomobject]@{
        File = $File.FullName; LinesRead = $lines; MatchingRecords = $matched; MalformedLines = $malformed
    })
}

$users = @{}
$minutes = @{}
$statuses = @{}
$httpErrors = @{}
$counts = @{ Requests = 0L; UnknownUserRequests = 0L }
$liveStatus = 'NotRequested'

try {
    if ($CollectLiveIIS) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Live IIS collection requires an elevated 64-bit Windows PowerShell session.'
        }
        if (-not [Environment]::Is64BitProcess) { throw 'Run live collection in 64-bit Windows PowerShell.' }
        $inetsrv = Join-Path $env:windir 'System32\inetsrv'
        Add-Type -Path (Join-Path $inetsrv 'Microsoft.Web.Administration.dll')
        $manager = [Microsoft.Web.Administration.ServerManager]::new()
        try {
            $site = $manager.Sites[$SiteName]
            if ($null -eq $site) { throw "IIS site not found: $SiteName" }
            $siteId = [long]$site.Id
            $poolNames = @($site.Applications | ForEach-Object { $_.ApplicationPoolName } | Sort-Object -Unique)
            $settings = @(
                foreach ($poolName in $poolNames) {
                    $pool = $manager.ApplicationPools[$poolName]
                    [pscustomobject]@{
                        Name = $pool.Name; State = $pool.State.ToString(); QueueLength = $pool.QueueLength
                        Runtime = $pool.ManagedRuntimeVersion; Pipeline = $pool.ManagedPipelineMode.ToString()
                        Enable32Bit = $pool.Enable32BitAppOnWin64
                        MaxProcesses = $pool.ProcessModel.MaxProcesses
                        IdleTimeout = $pool.ProcessModel.IdleTimeout.ToString()
                        RapidFailProtection = $pool.Failure.RapidFailProtection
                        RapidFailMaxCrashes = $pool.Failure.RapidFailProtectionMaxCrashes
                        RecycleInterval = $pool.Recycling.PeriodicRestart.Time.ToString()
                        RecyclePrivateMemoryKB = $pool.Recycling.PeriodicRestart.PrivateMemory
                        RecycleMemoryKB = $pool.Recycling.PeriodicRestart.Memory
                        RecycleSchedule = @($pool.Recycling.PeriodicRestart.Schedule | ForEach-Object { $_.Value.ToString() })
                    }
                }
            )
            $applications = @(
                foreach ($application in $site.Applications) {
                    $sessionMode = $null
                    $sessionTimeout = $null
                    $runtimeSettings = $null
                    try {
                        $webConfiguration = $manager.GetWebConfiguration($site.Name, $application.Path)
                        $section = $webConfiguration.GetSection('system.web/sessionState')
                        $sessionMode = [string]$section.GetAttributeValue('mode')
                        $sessionTimeout = [string]$section.GetAttributeValue('timeout')
                    } catch {
                        Add-CollectionWarning "Session-state settings unavailable for $($application.Path): $($_.Exception.Message)"
                    }
                    try {
                        $serverRuntime = $manager.GetWebConfiguration($site.Name, $application.Path).GetSection('system.webServer/serverRuntime')
                        $httpRuntime = $manager.GetWebConfiguration($site.Name, $application.Path).GetSection('system.web/httpRuntime')
                        $runtimeSettings = [pscustomobject]@{
                            AppConcurrentRequestLimit = $serverRuntime.GetAttributeValue('appConcurrentRequestLimit')
                            ClassicAspNetAppRequestQueueLimit = $httpRuntime.GetAttributeValue('appRequestQueueLimit')
                            ClassicAspNetExecutionTimeout = [string]$httpRuntime.GetAttributeValue('executionTimeout')
                            ClassicAspNetMinFreeThreads = $httpRuntime.GetAttributeValue('minFreeThreads')
                        }
                    } catch {
                        Add-CollectionWarning "Runtime limits unavailable for $($application.Path): $($_.Exception.Message)"
                    }
                    [pscustomobject]@{
                        Path = $application.Path; AppPool = $application.ApplicationPoolName
                        ClassicAspNetSessionMode = $sessionMode; ClassicAspNetSessionTimeout = $sessionTimeout
                        RuntimeSettings = $runtimeSettings
                    }
                }
            )
            Save-Json 'iis-settings.json' ([pscustomobject]@{
                Site = $site.Name; SiteId = $siteId; State = $site.State.ToString()
                MaxConnections = $site.Limits.MaxConnections
                LogFormat = $site.LogFile.LogFormat.ToString()
                LogDirectory = $site.LogFile.Directory
                LogFields = $site.LogFile.LogExtFileFlags.ToString()
                Bindings = @($site.Bindings | ForEach-Object { "$($_.Protocol) $($_.BindingInformation)" })
                Pools = $settings; Applications = $applications
            })
            if (-not $LogPath) {
                if ($site.LogFile.LogFormat.ToString() -ne 'W3C') {
                    Add-CollectionWarning 'Automatic log discovery requires per-site W3C file logging; supply LogPath for an exported W3C log.'
                } else {
                    $logRoot = [Environment]::ExpandEnvironmentVariables($site.LogFile.Directory)
                    $logFolder = Join-Path $logRoot "W3SVC$siteId"
                    $LogPath = @(Get-ChildItem -LiteralPath $logFolder -Filter '*.log' -File |
                        Where-Object { $_.LastWriteTimeUtc -ge $start.UtcDateTime } |
                        Select-Object -ExpandProperty FullName)
                    if (-not $LogPath) { Add-CollectionWarning "No recent per-site log files found in $logFolder." }
                }
            }
        } finally {
            $manager.Dispose()
        }

        $snapshots = [Collections.Generic.List[object]]::new()
        $processes = [Collections.Generic.List[object]]::new()
        $counterSamples = [Collections.Generic.List[object]]::new()
        $counterPaths = @(
            '\Processor(_Total)\% Processor Time', '\Memory\Available MBytes',
            '\HTTP Service Request Queues(*)\CurrentQueueSize',
            '\HTTP Service Request Queues(*)\RejectedRequests',
            '\ASP.NET Applications(*)\Requests Executing',
            '\ASP.NET Applications(*)\Requests In Application Queue',
            '\ASP.NET Applications(*)\Sessions Active',
            '\Web Service(*)\Current Connections',
            '\.NET CLR Memory(*)\% Time in GC'
        )
        $validCounters = [Collections.Generic.List[string]]::new()
        foreach ($path in $counterPaths) {
            try {
                $null = Get-Counter -Counter $path -MaxSamples 1 -ErrorAction Stop
                $validCounters.Add($path)
            } catch {
                Add-CollectionWarning "Counter unavailable (localization/runtime/instance/permissions): $path. $($_.Exception.Message)"
            }
        }
        $liveStart = [DateTimeOffset]::UtcNow
        for ($sample = 1; $sample -le $Samples; $sample++) {
            $sampleUtc = [DateTimeOffset]::UtcNow.ToString('o')
            $requests = [Collections.Generic.List[object]]::new()
            $requestStatus = 'Collected'
            $runtime = [Microsoft.Web.Administration.ServerManager]::new()
            try {
                foreach ($worker in $runtime.WorkerProcesses) {
                    if ($poolNames -notcontains $worker.AppPoolName) { continue }
                    try {
                        foreach ($request in $worker.GetRequests(0)) {
                            if ($request.SiteId -ne $siteId) { continue }
                            $requests.Add([pscustomobject]@{
                                Pool = $worker.AppPoolName; WorkerPid = $request.ProcessId
                                RequestId = [string]$request.RequestId
                                ElapsedMs = $request.TimeElapsed
                                Stage = $request.PipelineState.ToString(); Module = $request.CurrentModule
                                Verb = $request.Verb
                            })
                        }
                    } catch {
                        $requestStatus = 'PartialOrUnavailable'
                        Add-CollectionWarning "Live request sample $sample for worker $($worker.ProcessId) unavailable: $($_.Exception.Message)"
                    }
                    try {
                        $process = Get-Process -Id $worker.ProcessId -ErrorAction Stop
                        $processes.Add([pscustomobject]@{
                            Utc = $sampleUtc; Pool = $worker.AppPoolName; WorkerPid = $process.Id
                            StartUtc = $process.StartTime.ToUniversalTime().ToString('o')
                            CpuSecondsCumulative = $process.CPU
                            PrivateBytes = $process.PrivateMemorySize64; WorkingSetBytes = $process.WorkingSet64
                            Threads = $process.Threads.Count; Handles = $process.HandleCount
                        })
                    } catch {
                        Add-CollectionWarning "Worker $($worker.ProcessId) could not be sampled (possibly recycled): $($_.Exception.Message)"
                    }
                }
            } finally { $runtime.Dispose() }
            $snapshots.Add([pscustomobject]@{
                Sample = $sample; Utc = $sampleUtc; Status = $requestStatus
                ActiveRequests = $(if ($requestStatus -eq 'Collected') { $requests.Count } else { $null })
                Requests = $requests.ToArray()
            })
            if ($validCounters.Count -gt 0) {
                try {
                    $result = Get-Counter -Counter $validCounters.ToArray() -MaxSamples 1 -ErrorAction Stop
                    foreach ($counter in $result.CounterSamples) {
                        $counterSamples.Add([pscustomobject]@{
                            Utc = $counter.Timestamp.ToUniversalTime().ToString('o')
                            Path = $counter.Path; Value = $counter.CookedValue; Status = $counter.Status
                        })
                    }
                } catch {
                    Add-CollectionWarning "Performance sample $sample unavailable: $($_.Exception.Message)"
                }
            }
            if ($sample -lt $Samples) { Start-Sleep -Seconds $IntervalSeconds }
        }
        Save-Json 'live-requests.json' $snapshots.ToArray()
        Save-Csv 'worker-processes.csv' $processes.ToArray() @('Utc','Pool','WorkerPid','StartUtc','CpuSecondsCumulative','PrivateBytes','WorkingSetBytes','Threads','Handles')
        Save-Csv 'performance.csv' $counterSamples.ToArray() @('Utc','Path','Value','Status')
        Save-Json 'live-window.json' ([pscustomobject]@{ StartUtc = $liveStart.ToString('o'); EndUtc = [DateTimeOffset]::UtcNow.ToString('o') })
        $events = @()
        try {
            $events = @(Get-WinEvent -FilterHashtable @{
                LogName = 'System'; StartTime = $start.UtcDateTime; EndTime = $end.UtcDateTime
                ProviderName = @('Microsoft-Windows-WAS','Microsoft-Windows-IIS-W3SVC','Microsoft-Windows-IIS-W3SVC-WP')
            } -ErrorAction Stop | Select-Object @{n='Utc';e={$_.TimeCreated.ToUniversalTime().ToString('o')}}, Id, ProviderName, LevelDisplayName, Message)
        } catch {
            if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
                Add-CollectionWarning "System WAS/W3SVC events unavailable: $($_.Exception.Message)"
            }
        }
        Save-Json 'was-events.json' $events
        if (-not $HttpErrPath) {
            $errorFolder = Join-Path $env:windir 'System32\LogFiles\HTTPERR'
            if (Test-Path -LiteralPath $errorFolder) {
                $HttpErrPath = @(Get-ChildItem -LiteralPath $errorFolder -Filter '*.log' -File |
                    Where-Object { $_.LastWriteTimeUtc -ge $start.UtcDateTime } |
                    Select-Object -ExpandProperty FullName)
                if (-not $HttpErrPath) { Add-CollectionWarning "No recent HTTPERR files found in $errorFolder." }
            } else {
                Add-CollectionWarning 'Default HTTPERR directory not found; logging may be disabled or redirected. Supply HttpErrPath if needed.'
            }
        }
        $liveStatus = 'CompletedWithOptionalCoverageSeeWarnings'
    }

    foreach ($file in @(Resolve-LogFiles $LogPath)) {
        Read-W3C $file @('date','time','sc-status') {
            param($r, $timestamp, $missing)
            $status = $r['sc-status']
            if ($status -notmatch '^\d{3}$') { throw "Invalid sc-status in $($file.FullName): $status" }
            foreach ($name in @('sc-substatus','sc-win32-status','time-taken',$UserField)) {
                if (-not $r.ContainsKey($name)) { $missing[$name] = $true }
            }
            $substatus = if ($r.ContainsKey('sc-substatus')) { $r['sc-substatus'] } else { 'unknown' }
            $win32 = if ($r.ContainsKey('sc-win32-status')) { $r['sc-win32-status'] } else { 'unknown' }
            $key = "$status/$substatus/$win32"
            if (-not $statuses.ContainsKey($key)) { $statuses[$key] = 0L }
            $statuses[$key]++
            $counts.Requests++
            $minute = $timestamp.ToString('yyyy-MM-ddTHH:mm:00Z')
            if (-not $minutes.ContainsKey($minute)) {
                $minutes[$minute] = @{ Requests = 0L; Errors503 = 0L; DurationTotal = 0.0; DurationCount = 0L; MaxDuration = $null; Users = @{} }
            }
            $m = $minutes[$minute]
            $m.Requests++
            if ($status -eq '503') { $m.Errors503++ }
            $elapsed = 0.0
            if ($r.ContainsKey('time-taken') -and $r['time-taken'] -ne '-') {
                if (-not [double]::TryParse($r['time-taken'], [Globalization.NumberStyles]::None, $culture, [ref]$elapsed)) {
                    throw "Invalid time-taken in $($file.FullName)."
                }
                $m.DurationTotal += $elapsed
                $m.DurationCount++
                if ($null -eq $m.MaxDuration -or $elapsed -gt $m.MaxDuration) { $m.MaxDuration = $elapsed }
            }
            $user = if ($r.ContainsKey($UserField)) { $r[$UserField] } else { '-' }
            if ([string]::IsNullOrWhiteSpace($user) -or $user -eq '-') { $counts.UnknownUserRequests++; return }
            $m.Users[$user] = $true
            if ($UserName -and $user -ine $UserName) { return }
            if (-not $users.ContainsKey($user)) {
                $users[$user] = @{ Requests = 0L; Errors503 = 0L; First = $timestamp; Last = $timestamp; Sessions = @{}; HashRecordsKnown = 0L }
            }
            $u = $users[$user]
            $u.Requests++
            if ($status -eq '503') { $u.Errors503++ }
            if ($timestamp -lt $u.First) { $u.First = $timestamp }
            if ($timestamp -gt $u.Last) { $u.Last = $timestamp }
            if ($SessionHashField) {
                if (-not $r.ContainsKey($SessionHashField)) { $missing[$SessionHashField] = $true }
                else {
                    $u.HashRecordsKnown++
                    if ($r[$SessionHashField] -ne '-') {
                        if ($r[$SessionHashField] -notmatch '^[a-fA-F0-9]{64}$') {
                            throw 'SessionHashField must contain a dedicated 64-hex pseudonymous hash, not a raw cookie/session token.'
                        }
                        $u.Sessions[$r[$SessionHashField].ToLowerInvariant()] = $true
                    }
                }
            }
        }
    }

    foreach ($file in @(Resolve-LogFiles $HttpErrPath)) {
        Read-W3C $file @('date','time','s-status','s-reason') {
            param($r, $timestamp, $missing)
            $key = "$($r['s-status'])/$($r['s-reason'])"
            if (-not $httpErrors.ContainsKey($key)) { $httpErrors[$key] = 0L }
            $httpErrors[$key]++
        }
    }

    $sessionCounts = @{}
    if ($SessionInventoryPath) {
        $seenSessions = @{}
        Import-Csv -LiteralPath $SessionInventoryPath | ForEach-Object {
            $row = $_
            foreach ($column in @('UserId','SessionKeyHash','LastSeenUtc','ExpiresUtc','IsRevoked')) {
                if ($row.PSObject.Properties.Name -notcontains $column) { throw "Session inventory missing column: $column" }
            }
            if ([string]::IsNullOrWhiteSpace($row.UserId)) { throw 'Session inventory contains an empty UserId.' }
            if ($row.SessionKeyHash -notmatch '^[a-fA-F0-9]{64}$') { throw 'SessionKeyHash must be 64 hexadecimal characters, never a raw session token.' }
            if ($row.IsRevoked -notmatch '^(?i:true|false)$') { throw 'IsRevoked must be true or false.' }
            foreach ($column in @('LastSeenUtc','ExpiresUtc')) {
                if ($row.$column -notmatch '(Z|[+-]\d{2}:\d{2})$') { throw "$column requires an explicit timezone." }
            }
            $lastSeen = [DateTimeOffset]::Parse($row.LastSeenUtc, $culture)
            $expires = [DateTimeOffset]::Parse($row.ExpiresUtc, $culture)
            $hash = $row.SessionKeyHash.ToLowerInvariant()
            if ($seenSessions.ContainsKey($hash)) { throw 'Session inventory must contain one row per globally unique session hash. Deduplicate centrally, not by summing node counts.' }
            $seenSessions[$hash] = $true
            if ($UserName -and $row.UserId -ine $UserName) { return }
            if (-not $sessionCounts.ContainsKey($row.UserId)) { $sessionCounts[$row.UserId] = 0L }
            if ($lastSeen -le $end -and $expires -gt $end -and $row.IsRevoked -ieq 'false') {
                $sessionCounts[$row.UserId]++
            }
        }
        if ($seenSessions.Count -eq 0) { throw 'Session inventory is empty. Supply a validated application snapshot with the documented header.' }
    }

    $userRows = @(
        foreach ($user in ($users.Keys | Sort-Object)) {
            $u = $users[$user]
            [pscustomobject]@{
                Node = $NodeName; User = $user; CompletedRequests = $u.Requests; Errors503 = $u.Errors503
                FirstObservedUtc = $u.First.ToString('o'); LastObservedUtc = $u.Last.ToString('o')
                DistinctSessionHashesObserved = $(if ($SessionHashField -and $u.HashRecordsKnown -gt 0) { $u.Sessions.Count } else { $null })
                RequestsWithSessionField = $(if ($SessionHashField) { $u.HashRecordsKnown } else { $null })
                Meaning = 'ObservedInLogWindow_NotCurrentSessionsOrConcurrency'
            }
        }
    )
    $minuteRows = @(
        foreach ($minute in ($minutes.Keys | Sort-Object)) {
            $m = $minutes[$minute]
            [pscustomobject]@{
                Node = $NodeName; MinuteUtc = $minute; CompletedRequests = $m.Requests
                Errors503 = $m.Errors503; DistinctIdentifiedUsersObserved = $m.Users.Count
                TimedRequests = $m.DurationCount
                AverageTimeTakenMs = $(if ($m.DurationCount -gt 0) { [math]::Round($m.DurationTotal / $m.DurationCount, 2) } else { $null })
                MaxTimeTakenMs = $m.MaxDuration
            }
        }
    )
    $statusRows = @(
        foreach ($key in ($statuses.Keys | Sort-Object)) {
            $parts = $key.Split('/')
            [pscustomobject]@{ Node = $NodeName; Status = $parts[0]; Substatus = $parts[1]; Win32Status = $parts[2]; Requests = $statuses[$key] }
        }
    )
    $httpRows = @(
        foreach ($key in ($httpErrors.Keys | Sort-Object)) {
            $parts = $key.Split('/', 2)
            [pscustomobject]@{ Node = $NodeName; Status = $parts[0]; Reason = $parts[1]; Requests = $httpErrors[$key]; Scope = 'ServerWide_NotSiteFiltered' }
        }
    )
    $sessionRows = @(
        foreach ($user in ($sessionCounts.Keys | Sort-Object)) {
            [pscustomobject]@{
                User = $user; ActiveSessionsAsOfUtc = $end.ToString('o'); ActiveSessions = $sessionCounts[$user]
                Scope = 'SuppliedApplicationInventory_NotIIS'; Requirement = 'CompleteAuthoritativeSnapshotAsOfTimestamp'
            }
        }
    )
    Save-Csv 'users-observed.csv' $userRows @('Node','User','CompletedRequests','Errors503','FirstObservedUtc','LastObservedUtc','DistinctSessionHashesObserved','RequestsWithSessionField','Meaning')
    Save-Csv 'requests-by-minute.csv' $minuteRows @('Node','MinuteUtc','CompletedRequests','Errors503','DistinctIdentifiedUsersObserved','TimedRequests','AverageTimeTakenMs','MaxTimeTakenMs')
    Save-Csv 'http-status.csv' $statusRows @('Node','Status','Substatus','Win32Status','Requests')
    Save-Csv 'httperr-summary.csv' $httpRows @('Node','Status','Reason','Requests','Scope')
    Save-Csv 'application-sessions.csv' $sessionRows @('User','ActiveSessionsAsOfUtc','ActiveSessions','Scope','Requirement')
    if ($LogPath -and $counts.Requests -eq 0) { Add-CollectionWarning 'No IIS requests matched the UTC window; check the files, time conversion, site, log buffering and log availability.' }
    if ($counts.UnknownUserRequests -gt 0) {
        Add-CollectionWarning "$($counts.UnknownUserRequests) requests have no user identity. Forms authentication identities are not automatically written to cs-username."
    }
    if ($UserName -and $LogPath -and $userRows.Count -eq 0) {
        Add-CollectionWarning "No identified requests matched UserName '$UserName'; this does not prove that the user has no sessions."
    }
    if ($UserName -and $SessionInventoryPath -and $sessionRows.Count -eq 0) {
        Add-CollectionWarning "UserName '$UserName' was not present in the supplied session inventory. Session count is unknown, not zero."
    }
    Save-Json 'summary.json' ([pscustomobject]@{
        Node = $NodeName; LogWindowStartInclusiveUtc = $start.ToString('o'); LogWindowEndExclusiveUtc = $end.ToString('o')
        UserFilter = $UserName; FilterScope = 'UserReportsOnly_StatusAndMinuteReportsIncludeAllRequests'
        RequestsInLogs = $counts.Requests; RequestsWithoutIdentity = $counts.UnknownUserRequests
        LiveCollection = $liveStatus; SessionInventorySupplied = [bool]$SessionInventoryPath
        CurrentSessionsFromIIS = 'NotAvailable'; SessionHashField = $SessionHashField
        Notes = @(
            'Log counts are completed/logged requests, not in-flight concurrency. W3C records can be buffered.',
            'Observed session hashes are historical distinct identifiers, not active login sessions.',
            'Application counts are correct only for a complete authoritative snapshot at EndUtc.',
            'HTTPERR is server-wide. Pool counters/processes may include other sites in shared pools.',
            'Live samples occur at execution time, independently of the historical log window.',
            'Do not sum node-distinct session counts; a session may visit both nodes.',
            'Inspect coverage.json and warnings.json before drawing conclusions.'
        )
    })
    Save-Json 'coverage.json' $coverage.ToArray()
    Save-Json 'warnings.json' $warnings.ToArray()
    Write-Host "Collection complete: $($output.FullName)"
    Write-Host "Observed requests: $($counts.Requests). Missing user identity: $($counts.UnknownUserRequests)."
    if ($SessionInventoryPath) { $sessionRows | Format-Table User, ActiveSessions, ActiveSessionsAsOfUtc -AutoSize }
    elseif ($userRows.Count -gt 0) { $userRows | Format-Table User, CompletedRequests, Errors503, DistinctSessionHashesObserved -AutoSize }
    if ($warnings.Count -gt 0) { Write-Host "Coverage warnings: $($warnings.Count). Review warnings.json." }
} catch {
    Save-Json 'collection-failure.json' ([pscustomobject]@{
        Status = 'Failed_PartialFilesMustNotBeTreatedAsComplete'; Utc = [DateTimeOffset]::UtcNow.ToString('o')
        Error = $_.Exception.Message; Warnings = $warnings.ToArray()
    })
    throw
}
