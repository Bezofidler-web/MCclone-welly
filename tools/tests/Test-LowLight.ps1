#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$LuantiExe, [switch]$Visual)
$ErrorActionPreference = 'Stop'
$game = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$run = Join-Path $game ('local/test-runs/low-light-' + [Guid]::NewGuid().ToString('N'))
$world = Join-Path $run 'world'
$mod = Join-Path $world 'worldmods/low_light_probe'
[void](New-Item -ItemType Directory -Path $mod -Force)
Copy-Item -LiteralPath "$PSScriptRoot/low_light/init.lua","$PSScriptRoot/low_light/mod.conf" -Destination $mod
@'
gameid = mineclonia
world_name = Low Light Test
backend = sqlite3
player_backend = sqlite3
auth_backend = sqlite3
mod_storage_backend = sqlite3
load_mod_low_light_probe = true
enable_damage = false
creative_mode = true
'@ | Set-Content (Join-Path $world 'world.mt')
@'
mg_name = flat
mgflat_ground_level = 8
mobs_spawn = false
enable_damage = false
enable_sound = false
enable_post_processing = false
viewing_range = 88
screen_w = 800
screen_h = 520
display_gamma = 1.22
debug_log_level = action
static_spawnpoint = (0,41,0)
update_information_url =
'@ | Set-Content (Join-Path $run 'config.conf')
$log = Join-Path $run 'client.log'
$env:LUANTI_GAME_PATH = Split-Path $game -Parent
$env:MCL_LIGHT_TEST_WORLD = $world
$env:MCL_LIGHT_TEST_VISUAL = if ($Visual) { '1' } else { '0' }
$style = if ($Visual) { 'Normal' } else { 'Hidden' }
$arguments = '--go --world "' + $world + '" --config "' + (Join-Path $run 'config.conf') + '" --logfile "' + $log + '"'
$client = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $run -WindowStyle $style -PassThru
try {
    Write-Output "Test client $($client.Id) and log $log"
    $limit = [DateTime]::UtcNow.AddSeconds(240)
    while (![IO.File]::Exists($log) -or !(Select-String -LiteralPath $log -SimpleMatch '[low-light] PASS' -Quiet)) {
        if ($client.HasExited -or [DateTime]::UtcNow -gt $limit) { throw "Visibility regression failed. Inspect $log" }
        Start-Sleep -Milliseconds 400
    }
    Select-String -LiteralPath $log -SimpleMatch '[low-light] PASS' | ForEach-Object Line
    if ($Visual) {
        Write-Output "Write cave, old-cave, water, old-water or stop to $world\scene to switch views."
        [void]$client.WaitForExit(300000)
    }
} finally {
    if (!$client.HasExited) {
        [void]$client.CloseMainWindow()
        if (!$client.WaitForExit(5000)) { $client.Kill() }
    }
    $client.Dispose()
}
