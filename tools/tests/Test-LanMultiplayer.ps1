#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$LuantiExe)
$ErrorActionPreference = 'Stop'
$game = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$launcher = Join-Path $game 'tools/Start-VibrantClient.ps1'
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$run = Join-Path ([IO.Path]::GetTempPath()) ('mcwelly-qa-' + [Guid]::NewGuid().ToString('N'))
$worldName = 'LAN QA ' + (Split-Path -Leaf $run).Substring(11, 8)
$world = Join-Path $run 'worlds/world'
$mod = Join-Path $world 'worldmods/lan_probe'
$null = New-Item -ItemType Directory -Path $mod -Force
$children = [Collections.Generic.List[Diagnostics.Process]]::new()
Write-Host "Test world and evidence: $run"
@"
world_name = $worldName
gameid = $(Split-Path -Leaf $game)
backend = sqlite3
auth_backend = sqlite3
player_backend = sqlite3
mod_storage_backend = sqlite3
"@ | Set-Content -LiteralPath (Join-Path $world 'world.mt')
'name = lan_probe' | Set-Content -LiteralPath (Join-Path $mod 'mod.conf')
@'
local path = core.get_worldpath()
local storage = core.get_mod_storage()
core.register_on_joinplayer(function(player)
    if player:get_player_name() ~= "TestFriend" then return end
    core.after(2, function()
        local guest = assert(core.get_player_by_name("TestFriend"))
        assert(core.get_player_by_name("TestOwner") and #core.get_connected_players() == 2)
        local inventory = guest:get_inventory()
        if storage:get_int("visits") == 0 then
            inventory:set_stack("main", 1, ItemStack("mcl_core:diamond 3"))
            storage:set_int("visits", 1)
            core.kick_player("TestFriend", "First visit complete")
            assert(core.safe_file_write(path .. "/together", "2"))
        else
            assert(inventory:get_stack("main", 1):to_string() == "mcl_core:diamond 3")
            assert(core.safe_file_write(path .. "/returned", "3 diamonds"))
            core.request_shutdown("LAN test completed", false, 1)
        end
    end)
end)
'@ | Set-Content -LiteralPath (Join-Path $mod 'init.lua')

function Start-TestClient($Role) {
    $profile = if ($Role -eq 'returning') { 'guest' } else { $Role }
    $env:MCL_TEST_ROLE = $Role
    $env:LOCALAPPDATA = Join-Path $run $profile
    $config = Join-Path $run "$Role.conf"
    @"
main_menu_script = $(Join-Path $PSScriptRoot 'lan_menu.lua')
serverlist_url =
update_information_url =
enable_sound = false
enable_shaders = false
fps_max = 16
screen_w = 640
screen_h = 480
viewing_range = 24
mg_name = flat
mobs_spawn = false
mcl_levelgen_enable_ersatz = false
static_spawnpoint = (0, 9, 0)
server_announce = false
"@ | Set-Content -LiteralPath $config
    $process = & $launcher -LuantiExe $exe -Config $config -Profile Fast -LanInterface '127.0.0.1' -WindowStyle Hidden -PassThru -LogFile (Join-Path $run "$Role.log")
    $children.Add($process)
    return $process
}
function Wait-File($Path, $Seconds) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (![IO.File]::Exists($Path)) {
        if ($watch.Elapsed.TotalSeconds -gt $Seconds) { throw "Timed out waiting for $Path. Inspect $run." }
        foreach ($end in 'host-ended','guest-ended','returning-ended') {
            $ended = Join-Path $run $end
            if ($end -eq 'guest-ended' -and [IO.File]::Exists((Join-Path $world 'together'))) { continue }
            if ([IO.File]::Exists($ended) -and ![IO.File]::Exists((Join-Path $world 'returned'))) {
                throw "$end : $([IO.File]::ReadAllText($ended))"
            }
        }
        Start-Sleep -Milliseconds 250
    }
}
$saved = @{}
foreach ($name in 'LOCALAPPDATA','MCL_TEST_ROLE','MCL_TEST_MENU','MCL_TEST_WORLD','MCL_TEST_DIR','LUANTI_WORLD_PATH') {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name)
}
try {
    $env:MCL_TEST_MENU = Join-Path $game 'menu/title.lua'
    $env:MCL_TEST_WORLD = $worldName
    $env:MCL_TEST_DIR = $run
    $env:LUANTI_WORLD_PATH = Join-Path $run 'worlds'
    $guest = Start-TestClient 'guest'
    Wait-File (Join-Path $run 'guest-session') 30
    $owner = Start-TestClient 'host'
    Wait-File (Join-Path $world 'together') 240
    Write-Host 'PASS two players joined from the real Multiplayer menu through automatic loopback discovery'
    if (!$guest.HasExited) { $guest.Kill() }
    [void]$guest.WaitForExit(10000)
    Start-Sleep -Seconds 2
    $returning = Start-TestClient 'returning'
    Wait-File (Join-Path $world 'returned') 180
    Write-Host 'PASS restarting the client preserved the guest account and inventory'
} finally {
    foreach ($p in $children) {
        if (!$p.HasExited) { $p.Kill(); [void]$p.WaitForExit(10000) }
        $p.Dispose()
    }
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
}
