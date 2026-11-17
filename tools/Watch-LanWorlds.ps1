#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SessionDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{32}$')][string]$SessionId,
    [Parameter(Mandatory)][int]$LauncherId,
    [Parameter(Mandatory)][int]$NotifyPort,
    [string]$InterfaceAddress
)

$ErrorActionPreference = 'Stop'
$group = [Net.IPAddress]::Parse('239.255.72.19')
$destination = [Net.IPEndPoint]::new($group, 47719)
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$worldsFile = Join-Path $SessionDirectory 'worlds.json'
$statusFile = Join-Path $SessionDirectory 'status.json'
$hostFile = Join-Path $SessionDirectory 'host.json'
$known = @{}
$clock = [Diagnostics.Stopwatch]::StartNew()

function Publish-Json([string]$Path, [string]$Json) {
    $pending = "$Path.new"
    [IO.File]::WriteAllText($pending, $Json, $utf8)
    if ([IO.File]::Exists($Path)) {
        [IO.File]::Replace($pending, $Path, [NullString]::Value)
    } else {
        [IO.File]::Move($pending, $Path)
    }
}

function Read-SmallJson([string]$Path) {
    $file = [IO.FileInfo]::new($Path)
    if ($file.Exists -and $file.Length -gt 0 -and $file.Length -le 8192) {
        try { return ([IO.File]::ReadAllText($Path, $utf8) | ConvertFrom-Json -ErrorAction Stop) }
        catch { return $null } # Menu/engine may be replacing the file.
    }
}

function Test-World($Entry) {
    return $null -ne $Entry -and $Entry.id -is [string] -and $Entry.id -cmatch '^[a-f0-9]{32}$' -and
        $Entry.host -is [string] -and $Entry.host -cmatch '^[A-Za-z0-9_-]{1,20}$' -and
        $Entry.world -is [string] -and $Entry.world.Length -ge 1 -and $Entry.world.Length -le 128 -and $Entry.world -notmatch '[\x00-\x1F\x7F]' -and
        ($Entry.port -is [int] -or $Entry.port -is [long]) -and $Entry.port -ge 1 -and $Entry.port -le 65535
}

function Get-Announcement {
    $entry = Read-SmallJson $hostFile
    if (!$entry -or $entry.session -cne $SessionId -or $entry.world_path -isnot [string] -or
        ![IO.Path]::IsPathRooted($entry.world_path) -or $entry.world_path.StartsWith('\\')) { return }
    $packet = [ordered]@{ protocol = 'mcwelly-lan/1'; id = $entry.id; world = $entry.world_name; host = $entry.host; port = $entry.port }
    if (!(Test-World $packet)) { return }
    $ready = Read-SmallJson (Join-Path $entry.world_path 'mcl_lan_ready.json')
    if (!$ready -or $ready.session -cne $SessionId -or ($ready.time -isnot [int] -and $ready.time -isnot [long])) { return }
    $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $ready.time
    if ($age -lt 0 -or $age -ge 8) { return }
    return ,$utf8.GetBytes((ConvertTo-Json -InputObject $packet -Compress))
}

. (Join-Path $PSScriptRoot 'LanProfile.ps1')

function Wait-ForGame {
    $file = Join-Path $SessionDirectory 'client.json'
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $info = Read-SmallJson $file
        if ($info -and $info.id -gt 0) {
            $process = [Diagnostics.Process]::GetProcessById($info.id)
            if ($process.StartTime.ToUniversalTime().Ticks -eq [long]$info.started) { return $process }
            $process.Dispose()
            return
        }
        if ($launcher.HasExited) { return }
        Start-Sleep -Milliseconds 75
    } while ([DateTime]::UtcNow -lt $deadline)
}

$socket = $null
$notify = $null
$waiting = $null
$response = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 204 No Content`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
$client = $null
$launcher = $null
try {
    $launcher = [Diagnostics.Process]::GetProcessById($LauncherId)
    $socket = [Net.Sockets.UdpClient]::new([Net.Sockets.AddressFamily]::InterNetwork)
    $socket.ExclusiveAddressUse = $false
    $socket.Client.SetSocketOption('Socket', 'ReuseAddress', $true)
    $socket.Client.Bind([Net.IPEndPoint]::new([Net.IPAddress]::Any, $destination.Port))
    $socket.MulticastLoopback = $true
    $socket.Ttl = 1
    $socket.Client.SetSocketOption('IP', 'MulticastTimeToLive', 1)
    $active = @(foreach ($net in Get-LanInterfaces $InterfaceAddress) {
        try { $socket.JoinMulticastGroup($group, $net.Address); $net }
        catch [Net.Sockets.SocketException] { continue }
    })
    if (!$active.Count) { throw 'No local IPv4 multicast interface is available.' }
    # Menu Lua has async HTTP but no timer. A delayed empty reply wakes the
    # menu without polling the filesystem in a busy loop or returning secrets.
    try {
        $notify = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $NotifyPort)
        $notify.Start(2)
        Publish-Json (Join-Path $SessionDirectory 'notify.json') ('{"port":' + $NotifyPort + '}')
    } catch [Net.Sockets.SocketException] { $notify = $null }
    Publish-Json $worldsFile '[]'
    $client = Wait-ForGame
    if (!$client) { return }
    $previous = '[]'
    $nextAnnouncement = 0
    while (!$client.HasExited) {
        $now = $clock.ElapsedMilliseconds
        if ($now -ge $nextAnnouncement) {
            $nextAnnouncement = $now + 1500
            $packet = Get-Announcement
            if ($packet) {
                foreach ($net in $active) {
                    try {
                        $socket.Client.SetSocketOption('IP', 'MulticastInterface', $net.Address.GetAddressBytes())
                        [void]$socket.Send($packet, $packet.Length, $destination)
                    } catch [Net.Sockets.SocketException] { continue }
                }
            }
        }
        for ($i = 0; $i -lt 48 -and $socket.Available -gt 0; $i++) {
            $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
            $bytes = $socket.Receive([ref]$remote)
            if ($bytes.Length -gt 1200 -or $remote.Address.AddressFamily -ne 'InterNetwork') { continue }
            $localSource = $false
            foreach ($net in $active) {
                if (($remote.Address.Address -band $net.Mask.Address) -eq ($net.Address.Address -band $net.Mask.Address)) {
                    $localSource = $true
                    break
                }
            }
            if (!$localSource) { continue }
            try { $entry = $utf8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop }
            catch { continue }
            if ($entry.protocol -cne 'mcwelly-lan/1' -or !(Test-World $entry)) { continue }
            $key = "$($entry.id)@$($remote.Address):$($entry.port)"
            if ($known.Count -ge 128 -and !$known.ContainsKey($key)) { continue }
            $known[$key] = @{ Seen = $now; World = [ordered]@{
                id = $entry.id; host = $entry.host; world = $entry.world
                port = $entry.port; address = $remote.Address.ToString()
            } }
        }
        foreach ($key in @($known.Keys)) {
            if ($now - $known[$key].Seen -ge 5500) { $known.Remove($key) }
        }
        $rows = @(foreach ($key in ($known.Keys | Sort-Object)) { $known[$key].World })
        $json = ConvertTo-Json -Compress -InputObject $rows
        if ($json -cne $previous) {
            try { Publish-Json $worldsFile $json; $previous = $json }
            catch [IO.IOException] { } # Retry if the menu briefly holds the previous file.
        }
        if ($notify -and !$waiting -and $notify.Pending()) {
            $waiting = $notify.AcceptTcpClient()
            $wake = $now + 1500
        }
        if ($waiting -and $now -ge $wake) {
            try {
                $stream = $waiting.GetStream()
                # Consume the small GET header so closing Windows sockets
                # with unread request bytes cannot reset the response.
                if ($waiting.Available -gt 0) {
                    $header = [byte[]]::new([Math]::Min(8192, $waiting.Available))
                    [void]$stream.Read($header, 0, $header.Length)
                }
                $stream.Write($response, 0, $response.Length)
            } catch [IO.IOException] { }
            finally { $waiting.Dispose(); $waiting = $null }
        }
        [void]$client.WaitForExit(200)
    }
} catch {
    if ([IO.Directory]::Exists($SessionDirectory)) {
        Publish-Json $statusFile '{"error":"Local discovery is unavailable. Check your network connection and reopen the game."}'
    }
    if (!$client -and $launcher) { $client = Wait-ForGame }
    if ($client -and !$client.HasExited) { $client.WaitForExit() }
} finally {
    if ($socket) { $socket.Dispose() }
    if ($waiting) { $waiting.Dispose() }
    if ($notify) { $notify.Stop() }
    if ($client) { $client.Dispose() }
    if ($launcher) { $launcher.Dispose() }
    # Only remove files owned by this launcher. Never recurse into a world or user-selected path.
    if ((Split-Path -Leaf $SessionDirectory) -ceq "mcwelly-$SessionId") {
        foreach ($name in 'worlds.json','host.json','status.json','notify.json','client.json','worlds.json.new','status.json.new','notify.json.new') {
            [IO.File]::Delete((Join-Path $SessionDirectory $name))
        }
        if ([IO.Directory]::Exists($SessionDirectory) -and [IO.Directory]::GetFileSystemEntries($SessionDirectory).Length -eq 0) {
            [IO.Directory]::Delete($SessionDirectory)
        }
    }
}
