#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$LuantiExe,
    [string]$Config,
    [string]$TexturePack = (Join-Path $PSScriptRoot '..\local\textures\mineclonia-java-26.3'),
    [ValidateSet('Fast', 'Fancy', 'Vibrant')][string]$Profile = 'Vibrant',
    [switch]$PrepareOnly,
    [switch]$TitleScreen,
    [switch]$JavaUi,
    [string]$LanInterface,
    [string]$LogFile,
    [Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal',
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
$game = Split-Path $PSScriptRoot -Parent
$gamePath = Split-Path $game -Parent
$nativeClient = Join-Path $game 'local/java-client/bin/luanti.exe'
$stockClient = Join-Path $gamePath '.friends-work/luanti-5.18.0-win64/bin/luanti.exe'
$explicitClient = [bool]$LuantiExe
if ($explicitClient) {
    $candidates = @((Resolve-Path -LiteralPath $LuantiExe).Path)
} else {
    $candidates = @(
        if ($JavaUi) { $nativeClient }
        else {
            (Join-Path $game 'local/luanti/bin/luanti.exe')
            $stockClient
            (Join-Path $env:ProgramFiles 'Luanti/bin/luanti.exe')
            (Get-Command luanti.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
            $nativeClient
        }
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -Unique
    if (!$candidates) {
        throw 'Install Luanti 5.18 for Windows and put its extracted bin, builtin and other folders inside local\luanti. Then open Play Mineclonia.cmd again.'
    }
}
$utf8 = [Text.UTF8Encoding]::new($false)
function Set-ConfigLines($Lines) {
    [IO.File]::WriteAllLines($configPath, [string[]]$Lines, $utf8)
}
function Add-ConfigLines($Lines) {
    [IO.File]::AppendAllLines($configPath, [string[]]$Lines, $utf8)
}
$fileName = $Profile.ToLowerInvariant() + '-client.conf'
if (-not $Config) {
    $configName = if ($JavaUi) { "java26.3-$fileName" } else { $fileName }
    $Config = Join-Path $game 'local' $configName
}
$configPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config)
$template = Join-Path $game "$fileName.example"
if (-not (Test-Path -LiteralPath $configPath)) {
    $settings = Get-Content -LiteralPath $template
    if ($TexturePack -and (Test-Path -LiteralPath $TexturePack -PathType Container)) {
        $settings += 'texture_path = ' + (Resolve-Path -LiteralPath $TexturePack).Path
    }
    [void][IO.Directory]::CreateDirectory((Split-Path $configPath -Parent))
    Set-ConfigLines $settings
} else {
    # Existing profiles pick up new defaults without replacing explicit choices.
    $legacyRange = @{ Fast = 112; Fancy = 192; Vibrant = 176 }[$Profile]
    $lines = @(Get-Content -LiteralPath $configPath)
    $rangePattern = '^\s*viewing_range\s*=\s*' + $legacyRange + '\s*$'
    if ($lines -match $rangePattern) {
        $newRange = (Select-String -LiteralPath $template -Pattern '^viewing_range\s*=').Line
        Set-ConfigLines ($lines -replace $rangePattern, $newRange)
    }
    $defaults = foreach ($setting in 'display_gamma', 'pitch_move', 'viewing_range') {
        $pattern = "^\s*$setting\s*="
        if (-not (Select-String -LiteralPath $configPath -Pattern $pattern -Quiet)) {
            (Select-String -LiteralPath $template -Pattern $pattern).Line
        }
    }
    if ($defaults) {
        Add-ConfigLines (@('') + $defaults)
    }
}

$uiDefaults = [ordered]@{
    menu_clouds = 'false'
    console_color = '(0,0,0)'
    console_alpha = '128'
}
$font = Join-Path $game 'menu/font/Minecraft.otf'
$configuredFont = Select-String -LiteralPath $configPath -Pattern '^\s*font_path\s*=' | Select-Object -First 1
if (Test-Path -LiteralPath $font -PathType Leaf) {
    if (!$configuredFont -or ($configuredFont.Line -split '=', 2)[1].Trim() -eq $font) {
        $uiDefaults['font_path'] = $font
        $uiDefaults['font_path_bold'] = Join-Path $game 'menu/font/Minecraft-Bold.otf'
    }
}
$monoFont = Join-Path $game 'menu/font/Monocraft.ttf'
if ((Test-Path -LiteralPath $monoFont -PathType Leaf) -and
    !(Select-String -LiteralPath $configPath -Pattern '^\s*mono_font_path\s*=' -Quiet)) {
    $uiDefaults['mono_font_path'] = $monoFont
    $uiDefaults['mono_font_size'] = '15'
}
$appearance = foreach ($key in $uiDefaults.Keys) {
    if (-not (Select-String -LiteralPath $configPath -Pattern "^\s*$key\s*=" -Quiet)) {
        "$key = $($uiDefaults[$key])"
    }
}
if ($appearance) {
    Add-ConfigLines (@('') + $appearance)
}

if ($JavaUi -or (!$explicitClient -and @($candidates)[0] -eq $nativeClient)) {
    $lines = @(Get-Content -LiteralPath $configPath)
    $javaUiPattern = '^\s*mcl_java_ui\s*='
    $existing = @($lines -match $javaUiPattern)
    if ($existing.Count -ne 1 -or $existing[0] -ne 'mcl_java_ui = true') {
        Set-ConfigLines (@($lines -notmatch $javaUiPattern) + 'mcl_java_ui = true')
    }
}

$loadingPack = Join-Path $game 'menu/loading'
$textureSetting = Select-String -LiteralPath $configPath -Pattern '^\s*texture_path\s*=' | Select-Object -Last 1
if (!$textureSetting) {
    Add-ConfigLines @("texture_path = $loadingPack")
} else {
    $packPaths = ($textureSetting.Line -split '=', 2)[1].Trim()
    $separator = [IO.Path]::PathSeparator
    if ($loadingPack -notin $packPaths.Split($separator, [StringSplitOptions]::RemoveEmptyEntries)) {
        $lines = @(Get-Content -LiteralPath $configPath)
        $packs = if ($packPaths) { $packPaths + $separator + $loadingPack } else { $loadingPack }
        $lines[$textureSetting.LineNumber - 1] = "texture_path = $packs"
        Set-ConfigLines $lines
    }
}

if ($TitleScreen -or -not $PrepareOnly) {
    $menu = Join-Path $game 'menu/title.lua'
    $menuSetting = "main_menu_script = $menu"
    $menuPattern = '^\s*main_menu_script\s*='
    $lines = @(Get-Content -LiteralPath $configPath)
    $existingMenu = @($lines -match $menuPattern)
    if (!$existingMenu) {
        Add-ConfigLines @('', $menuSetting)
    } elseif ($TitleScreen -and ($existingMenu.Count -ne 1 -or $existingMenu[0] -ne $menuSetting)) {
        Set-ConfigLines (@($lines -notmatch $menuPattern) + $menuSetting)
    }
}
if ($PrepareOnly) {
    $configPath
    return
}

if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    $start = [Diagnostics.ProcessStartInfo]::new(@($candidates)[0])
    $start.UseShellExecute = $false
    $start.EnvironmentVariables['LUANTI_GAME_PATH'] = $gamePath
    $start.EnvironmentVariables['MCL_GAME_ID'] = (Split-Path -Leaf $game) -creplace '(.+)_game$', '$1'
    $start.ArgumentList.Add('--config')
    $start.ArgumentList.Add($configPath)
    $client = [Diagnostics.Process]::Start($start)
    if ($PassThru) { return $client }
    $client.Dispose()
    return
}
. (Join-Path $PSScriptRoot 'LanProfile.ps1')
$client = $null
$directory = $null
$lanProblem = $null
try {
    $identity = Get-LanProfileKey (Join-Path $env:LOCALAPPDATA 'mcWelly')
    $session = [Guid]::NewGuid().ToString('N')
    $directory = Join-Path ([IO.Path]::GetTempPath()) "mcwelly-$session"
    [void][IO.Directory]::CreateDirectory($directory)
    $portProbe = [Net.Sockets.UdpClient]::new(0)
    try { $availablePort = $portProbe.Client.LocalEndPoint.Port } finally { $portProbe.Dispose() }
    $notifyProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try { $notifyProbe.Start(); $notifyPort = $notifyProbe.LocalEndpoint.Port } finally { $notifyProbe.Stop() }
    $networks = @(Get-LanInterfaces $LanInterface | ForEach-Object { "$($_.Address)/$($_.Mask)" }) -join ','
    $watch = Join-Path $PSScriptRoot 'Watch-LanWorlds.ps1'
    $arguments = '-NoLogo -NoProfile -NonInteractive -File "' + $watch + '" -SessionDirectory "' +
        $directory + '" -SessionId ' + $session + ' -LauncherId ' + $PID + ' -NotifyPort ' + $notifyPort
    if ($LanInterface) { $arguments += ' -InterfaceAddress ' + ([Net.IPAddress]::Parse($LanInterface)).ToString() }
    $shell = (Get-Process -Id $PID).Path
    $watcher = Start-Process -FilePath $shell -ArgumentList $arguments -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    try {
        while (!$watcher.HasExited -and [DateTime]::UtcNow -lt $deadline -and
            ![IO.File]::Exists((Join-Path $directory 'worlds.json')) -and ![IO.File]::Exists((Join-Path $directory 'status.json'))) {
            Start-Sleep -Milliseconds 75
        }
        if ($watcher.HasExited) {
            [IO.File]::WriteAllText((Join-Path $directory 'status.json'), '{"error":"Windows could not start local discovery."}', $utf8)
        }
    } finally { $watcher.Dispose() }
} catch {
    $lanProblem = 'Windows could not initialise local multiplayer. Check your network and Windows user profile, then reopen the game.'
    Write-Warning $lanProblem
}
try {
    foreach ($exe in $candidates) {
        $start = [Diagnostics.ProcessStartInfo]::new($exe)
        $start.UseShellExecute = $false
        $start.Arguments = '--config "' + $configPath + '"'
        if ($LogFile) { $start.Arguments += ' --logfile "' + $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogFile) + '"' }
        $start.WindowStyle = $WindowStyle
        $environment = $start.EnvironmentVariables
        $environment['LUANTI_GAME_PATH'] = $gamePath
        $environment['MINETEST_GAME_PATH'] = $gamePath
        $environment['MCL_GAME_ID'] = (Split-Path -Leaf $game) -creplace '(.+)_game$', '$1'
        if ($lanProblem) {
            $environment['MCL_LAN_ERROR'] = $lanProblem
            $environment.Remove('MCL_LAN_SESSION_ID')
        } else {
            $environment['MCL_LAN_SESSION_DIR'] = $directory
            $environment['MCL_LAN_SESSION_ID'] = $session
            $environment['MCL_LAN_PORT'] = [string]$availablePort
            $environment['MCL_LAN_NOTIFY_PORT'] = [string]$notifyPort
            $environment['MCL_LAN_PROFILE_KEY'] = $identity
            $environment['MCL_LAN_NETWORKS'] = $networks
            if ($LanInterface) { $environment['MCL_LAN_BIND_ADDRESS'] = ([Net.IPAddress]::Parse($LanInterface)).ToString() }
        }
        # Keep existing click-to-play saves visible if switching from the portable engine.
        if (!$explicitClient -and $exe -ne $stockClient -and (Test-Path -LiteralPath $stockClient)) {
            $oldWorlds = Join-Path (Split-Path -Parent (Split-Path -Parent $stockClient)) 'worlds'
            $environment['LUANTI_WORLD_PATH'] = (@($environment['LUANTI_WORLD_PATH'], $oldWorlds) -ne '') -join ';'
        }
        try { $client = [Diagnostics.Process]::Start($start); break }
        catch [System.ComponentModel.Win32Exception] {
            if ($explicitClient -or $exe -eq @($candidates)[-1]) { throw }
            Write-Warning "Windows could not start $exe. Trying the next installed Luanti client."
        }
    }
    if ($directory -and !$lanProblem) {
        $processInfo = @{ id = $client.Id; started = $client.StartTime.ToUniversalTime().Ticks.ToString() }
        [IO.File]::WriteAllText((Join-Path $directory 'client.json'), (ConvertTo-Json -InputObject $processInfo -Compress), $utf8)
    }
    if ($PassThru) { return $client }
} catch {
    if ($client -and !$client.HasExited) {
        [IO.File]::WriteAllText((Join-Path $directory 'status.json'), '{"error":"Local discovery could not start. Reopen the game to try again."}', $utf8)
    } elseif ($directory -and [IO.Directory]::Exists($directory) -and [IO.Directory]::GetFileSystemEntries($directory).Length -eq 0) {
        [IO.Directory]::Delete($directory)
    }
    throw
} finally {
    if ($client -and !$PassThru) { $client.Dispose() }
}
