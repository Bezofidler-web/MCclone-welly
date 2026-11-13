#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LuantiExe,
    [string]$Config = (Join-Path $PSScriptRoot '..\local\vibrant-client.conf'),
    [string]$TexturePack = (Join-Path $PSScriptRoot '..\local\textures\mineclonia-java-26.3')
)

$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $LuantiExe).Path
$configPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Config)
if (-not (Test-Path -LiteralPath $configPath)) {
    $template = Join-Path $PSScriptRoot '..\vibrant-client.conf.example'
    $settings = Get-Content -LiteralPath $template
    if ($TexturePack -and (Test-Path -LiteralPath $TexturePack -PathType Container)) {
        $settings += 'texture_path = ' + (Resolve-Path -LiteralPath $TexturePack).Path
    }
    [void][IO.Directory]::CreateDirectory((Split-Path $configPath -Parent))
    $settings | Set-Content -LiteralPath $configPath -Encoding utf8NoBOM
}

$game = Split-Path $PSScriptRoot -Parent
$gamePath = Split-Path $game -Parent
$start = [Diagnostics.ProcessStartInfo]::new($exe)
$start.Environment['LUANTI_GAME_PATH'] = $gamePath
$start.Environment['MINETEST_GAME_PATH'] = $gamePath
$start.ArgumentList.Add('--config')
$start.ArgumentList.Add($configPath)
$client = [Diagnostics.Process]::Start($start)
$client.Dispose()
