#Requires -Version 7.0
# Exercise the discovery transport independently of game loading time.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('mcwelly-discovery-test-' + [Guid]::NewGuid().ToString('N'))
$id = [Guid]::NewGuid().ToString('N')
$world = Join-Path $root 'world'
$dir = Join-Path $root "mcwelly-$id"
$null = New-Item -ItemType Directory -Path $world,$dir
$socket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
try { $socket.Start(); $port = $socket.LocalEndpoint.Port } finally { $socket.Stop() }
$testProcess = Get-Process -Id $PID
$identity = @{ id = $PID; started = $testProcess.StartTime.ToUniversalTime().Ticks.ToString() }
$identity | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'client.json')
$info = @{ session = $id; id = $id; world_name = 'Discovery test'; host = 'Owner'; port = 30590; world_path = $world }
$info | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dir 'host.json')
$watch = Join-Path (Split-Path $PSScriptRoot -Parent) 'Watch-LanWorlds.ps1'
$argsLine = "-NoProfile -File `"$watch`" -SessionDirectory `"$dir`" -SessionId $id -LauncherId $PID -NotifyPort $port -InterfaceAddress 127.0.0.1"
$worker = Start-Process -FilePath $testProcess.Path -ArgumentList $argsLine -WindowStyle Hidden -PassThru
function Wait-WorldCount($Expected) {
    $list = Join-Path $dir 'worlds.json'
    $deadline = [DateTime]::UtcNow.AddSeconds(18)
    do {
        if ($worker.HasExited) { throw 'Discovery exited before the test finished.' }
        if ([IO.File]::Exists($list)) {
            $rows = @(Get-Content -Raw -LiteralPath $list | ConvertFrom-Json | Where-Object id -eq $id)
            if ($rows.Count -eq $Expected) {
                if ($Expected -and ($rows[0].address -ne '127.0.0.1' -or $rows[0].port -ne 30590)) { throw 'Wrong endpoint' }
                return
            }
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Expected $Expected matching worlds."
}
try {
    Wait-WorldCount 0
    $ready = Join-Path $world 'mcl_lan_ready.json'
    @{session=$id; time=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()} | ConvertTo-Json | Set-Content -LiteralPath $ready
    Wait-WorldCount 1
    [IO.File]::Delete($ready)
    Wait-WorldCount 0
    'PASS a world appears after the host is ready, uses its packet source address and expires after the host stops.'
} finally {
    if (!$worker.HasExited) { $worker.Kill(); $null = $worker.WaitForExit(10000) }
    $worker.Dispose()
    $testProcess.Dispose()
}
