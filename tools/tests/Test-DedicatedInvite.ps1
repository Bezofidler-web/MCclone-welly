#Requires -Version 7.0
param([Parameter(Mandatory)][string]$LuantiExe, [ValidateRange(1024,65535)][int]$Port = 31883, [switch]$FullGame)
$ErrorActionPreference = 'Stop'
$game = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$root = Split-Path $game -Parent
$run = Join-Path $game ('local/test-runs/dedicated-invite-' + [Guid]::NewGuid().ToString('N'))
$world = Join-Path $run 'world'
$mod = Join-Path $world 'worldmods/invite_probe'
$null = New-Item -ItemType Directory -Path $mod,(Join-Path $run 'host'),(Join-Path $run 'guest'),(Join-Path $run 'server') -Force
$exe = (Get-Command $LuantiExe -CommandType Application -ErrorAction Stop).Source
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dedicated_invite/init.lua') -Destination $mod
@('name = invite_probe','depends = mcl_friends') | Set-Content (Join-Path $mod 'mod.conf')
$gameId = Split-Path $game -Leaf
$gamePath = $root
if (!$FullGame) {
    # Exercise the real private accounts and menu with a small fixture world.
    # Only the unrelated player-settings button hook is stubbed.
    $gameId = 'invite_test'
    $gamePath = Join-Path $run 'games'
    $fixture = Join-Path $gamePath $gameId
    $stub = Join-Path $fixture 'mods/mcl_player'
    $media = Join-Path $stub 'textures'
    $null = New-Item -ItemType Directory -Path $media -Force
    foreach ($file in 'mcl_options_button.png','mcl_options_button_highlighted.png') {
        Copy-Item -LiteralPath (Join-Path $game "mods/PLAYER/mcl_player/textures/$file") -Destination $media
    }
    Copy-Item -LiteralPath (Join-Path $game 'mods/MISC/mcl_friends') -Destination (Join-Path $fixture 'mods') -Recurse
    'title = Dedicated invite test' | Set-Content (Join-Path $fixture 'game.conf')
    'name = mcl_player' | Set-Content (Join-Path $stub 'mod.conf')
    @('mcl_player = {register_player_settings_button = function() end}', 'mcl_weather = false',
        'core.register_node("mcl_player:stone", {description = "Stone", tiles = {"unknown_node.png"}})',
        'core.register_alias("mapgen_stone", "mcl_player:stone")',
        'core.register_alias("mapgen_water_source", "air")',
        'core.register_alias("mapgen_river_water_source", "air")') | Set-Content (Join-Path $stub 'init.lua')
}
@("gameid = $gameId",'backend = sqlite3','player_backend = sqlite3','auth_backend = sqlite3','mod_storage_backend = sqlite3') |
    Set-Content (Join-Path $world 'world.mt')
@('name = InviteHost','bind_address = 127.0.0.1',"port = $Port","mcl_friends_invite_address = 127.0.0.1:$Port",
    'mcl_friends_only = true','disallow_empty_password = true','server_announce = false','mobs_spawn = false','mg_name = flat',
    'mcl_singlenode_mapgen = true','mcl_levelgen_enable_ersatz = false','static_spawnpoint = (0,9,0)') | Set-Content (Join-Path $run 'server.conf')
Write-Output "Test logs: $run"
$key = [Guid]::NewGuid().ToString('N')
$code = $null
$children = [Collections.Generic.List[Diagnostics.Process]]::new()
function Start-Probe($role, $arguments, $extra) {
    $start = [Diagnostics.ProcessStartInfo]::new($exe)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = 'Hidden'
    $start.WorkingDirectory = $run
    $start.Environment['LUANTI_GAME_PATH'] = $gamePath
    $start.Environment['LUANTI_USER_PATH'] = Join-Path $run $role
    $start.Environment['MCW_QA_PORT'] = [string]$Port
    foreach ($name in $extra.Keys) { $start.Environment[$name] = $extra[$name] }
    foreach ($arg in $arguments) { $start.ArgumentList.Add($arg) }
    $start.ArgumentList.Add('--logfile')
    $start.ArgumentList.Add((Join-Path $run "$role.log"))
    $p = [Diagnostics.Process]::Start($start)
    $children.Add($p)
    return $p
}
function Wait-For($file, $check, $p, $seconds) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $seconds) {
        if ((Test-Path -LiteralPath $file) -and (Select-String -LiteralPath $file -SimpleMatch $check -Quiet)) { return }
        if ($p.HasExited) { throw "Client exited with code $($p.ExitCode) before $check" }
        Start-Sleep -Milliseconds 350
    }
    throw "Timed out waiting for $check"
}
$secretFile = Join-Path $run 'host.tmp'
$inviteFile = Join-Path $run 'world/invite.tmp'
try {
    [IO.File]::WriteAllText($secretFile, $key)
    $common = @('enable_sound = false', 'enable_shaders = false','max_fps = 15','viewing_range = 24','screen_w = 640','screen_h = 440','update_information_url =','serverlist_url =')
    ($common + 'video_driver = opengl') | Set-Content (Join-Path $run 'host.conf')
    ($common + 'video_driver = opengl3' + ('main_menu_script = ' + (Join-Path $PSScriptRoot 'dedicated_invite/menu.lua'))) | Set-Content (Join-Path $run 'guest.conf')
    $server = Start-Probe 'server' @('--server','--world',(Join-Path $run 'world'),'--config',(Join-Path $run 'server.conf')) @{MCW_QA_HOST_KEY=$key}
    Wait-For (Join-Path $run 'server.log') "listening on 127.0.0.1:$Port" $server 240
    $hostClient = Start-Probe 'host' @('--go','--name','InviteHost','--address','127.0.0.1','--port',"$Port",'--password-file',$secretFile,'--config',(Join-Path $run 'host.conf')) @{}
    Wait-For (Join-Path $run 'server.log') '[dedicated-invite] host account control issued' $hostClient 150
    $code = [IO.File]::ReadAllText($inviteFile)
    $guest = Start-Probe 'guest' @('--config',(Join-Path $run 'guest.conf')) @{MCW_QA_INVITE=$code; MCW_QA_TITLE=(Join-Path $game 'menu/title.lua')}
    Wait-For (Join-Path $run 'server.log') '[dedicated-invite] PASS invited guest joined' $guest 160
    Wait-For (Join-Path $run 'guest.log') '[dedicated-invite] PASS malformed rejection' $guest 20
    $body = $code.Substring(5)
    $body += '=' * ((4 - $body.Length % 4) % 4)
    $secret = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($body)).Split('|'))[-1]
    foreach ($file in (Get-ChildItem -LiteralPath $run -Recurse -File -Include '*.log','*.conf','debug.txt')) {
        if (Select-String -LiteralPath $file.FullName -Pattern $key,$secret,$code -SimpleMatch -Quiet) { throw "Credential in $($file.Name)" }
    }
    Write-Output 'PASS hosted, issued, reviewed, cancelled, joined and checked credentials absent from logs/configs.'
} finally {
    foreach ($child in $children) { if (!$child.HasExited) { $child.Kill() }; $child.Dispose() }
    foreach ($file in @($secretFile,$inviteFile)) { if ([IO.File]::Exists($file)) { [IO.File]::Delete($file) } }
}
