#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$LuantiExe,
    [string]$Config = (Join-Path $PSScriptRoot '..\local\friends-server.conf'),
    [string]$World = (Join-Path $PSScriptRoot '..\local\world'),
    [ValidatePattern('^[A-Za-z0-9_-]{1,20}$')][string]$HostName,
    [switch]$ResetHostPassword
)

$ErrorActionPreference = 'Stop'
$game = Split-Path $PSScriptRoot -Parent
if (!$LuantiExe) {
    $LuantiExe = @(
        (Join-Path $game 'local/luanti/bin/luanti.exe')
        (Join-Path $game '../.friends-work/luanti-5.18.0-win64/bin/luanti.exe')
        (Get-Command luanti -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
}
if (!$LuantiExe -or !(Test-Path -LiteralPath $LuantiExe -PathType Leaf)) {
    throw 'Luanti was not found. Pass -LuantiExe with the path to bin\luanti.exe from Luanti 5.18 or later.'
}

$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$configPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config)
$worldPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($World)
$log = Join-Path (Split-Path $configPath -Parent) 'server.log'
$gameId = (Split-Path $game -Leaf) -creplace '(.+)_game$', '$1'
$gamePath = Split-Path $game -Parent

if ($HostName -ieq 'singleplayer') { throw 'Choose a multiplayer name other than singleplayer.' }
$newConfig = !(Test-Path -LiteralPath $configPath -PathType Leaf)
if ($newConfig -and !$HostName) {
    throw 'Pass -HostName followed by your chosen player name to create a private server config. See FRIENDS.md.'
}
$configLines = @(if ($newConfig) {
    Get-Content -LiteralPath (Join-Path $game 'friends-server.conf.example')
} else {
    Get-Content -LiteralPath $configPath
})
$settings = @{}
$nameLine = -1
$inMultiline = $false
$groupDepth = 0
for ($index = 0; $index -lt $configLines.Count; $index++) {
    $line = $configLines[$index]
    if ($inMultiline) {
        if ($line -ceq '"""') { $inMultiline = $false }
        continue
    }
    if ($line -match '^\s*[^#=\s][^=]*=\s*("""|\{)\s*$') {
        if ($Matches[1] -eq '"""') { $inMultiline = $true }
        else { $groupDepth++ }
        continue
    }
    if ($line.Trim() -eq '}' -and $groupDepth -gt 0) { $groupDepth-- }
    if ($groupDepth -eq 0 -and $line -cmatch '^\s*(name|mcl_friends_only|port|bind_address)\s*=\s*(.*?)\s*$') {
        $key = $Matches[1]
        $settings[$key] = $Matches[2]
        if ($key -ceq 'name') { $nameLine = $index }
    }
}
$private = $settings.mcl_friends_only -in 'true', 'yes', 'y', '1'
if ($settings.ContainsKey('mcl_friends_only') -and !$private -and
    $settings.mcl_friends_only -notin 'false', 'no', 'n', '0') {
    throw "Set mcl_friends_only to true or false in $configPath."
}
if (($ResetHostPassword -or $HostName) -and !$private) {
    throw 'Host account setup requires mcl_friends_only = true.'
}
if ($HostName -and $settings.name -and $settings.name -cne $HostName) {
    throw "This config uses host name '$($settings.name)'. Use that exact name to keep the host's existing account."
}
if ($private -and !$settings.name -and !$HostName) {
    throw "Set name in $configPath or pass -HostName with your exact player name."
}
$port = 30000
if ($settings.ContainsKey('port')) {
    if ($settings.port -notmatch '^\d+$' -or ![int]::TryParse($settings.port, [ref]$port) -or $port -gt 65535) {
        throw "Set port to a number from 1 to 65535 in $configPath."
    }
    if ($port -eq 0) { $port = 30000 }
}

if ($HostName -and !$settings.name) {
    if ($nameLine -ge 0) { $configLines[$nameLine] = "name = $HostName" }
    else { $configLines += "name = $HostName" }
    [void][IO.Directory]::CreateDirectory((Split-Path $configPath -Parent))
    $configLines | Set-Content -LiteralPath $configPath -Encoding utf8NoBOM
}

Write-Host "World: $worldPath"
Write-Host "Luanti uses UDP port $port. Join once the server reports it is listening."
$bind = $settings.bind_address
if (!$bind -or $bind -in '0.0.0.0', '::') {
    Write-Host "On this PC: 127.0.0.1:$port"
    try {
        foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($adapter.OperationalStatus -ne 'Up' -or $adapter.NetworkInterfaceType -eq 'Loopback') { continue }
            foreach ($entry in $adapter.GetIPProperties().UnicastAddresses) {
                $address = $entry.Address
                if ($address.AddressFamily -eq 'InterNetwork' -and
                    ![Net.IPAddress]::IsLoopback($address) -and "$address" -notlike '169.254.*') {
                    Write-Host ("{0}: {1}:{2}" -f $adapter.Name, $address, $port)
                }
            }
        }
    } catch [Net.NetworkInformation.NetworkInformationException] {
        Write-Warning 'Could not list network addresses. Run ipconfig to find the IPv4 address of this PC.'
    }
} else {
    $endpoint = if ($bind.Contains(':')) { "[${bind}]:$port" } else { "${bind}:$port" }
    $ip = $null
    if ($bind -eq 'localhost' -or ([Net.IPAddress]::TryParse($bind, [ref]$ip) -and [Net.IPAddress]::IsLoopback($ip))) {
        Write-Host "On this PC only: $endpoint"
    } else {
        Write-Host "Configured join address: $endpoint"
    }
}
Write-Host "Server log: $log"

$start = [Diagnostics.ProcessStartInfo]::new($exe)
$start.Environment['LUANTI_GAME_PATH'] = $gamePath
$start.Environment['MINETEST_GAME_PATH'] = $gamePath
$start.Environment['MCL_FRIENDS_CONSOLE'] = '1'
$start.Environment['MCL_FRIENDS_RESET_HOST'] = if ($ResetHostPassword) { '1' } else { '0' }
foreach ($argument in '--server', '--console', '--gameid', $gameId, '--config', $configPath, '--world', $worldPath, '--logfile', $log) {
    $start.ArgumentList.Add($argument)
}
$server = [Diagnostics.Process]::Start($start)
try {
    $server.WaitForExit()
    if ($server.ExitCode -ne 0) { throw "Luanti exited with code $($server.ExitCode). See $log." }
} finally {
    $server.Dispose()
}
