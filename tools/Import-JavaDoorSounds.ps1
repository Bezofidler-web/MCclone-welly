#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AssetIndex,
    [string]$AssetsDirectory = (Join-Path $env:APPDATA '.minecraft/assets')
)

$ErrorActionPreference = 'Stop'
$objects = (Get-Content -LiteralPath $AssetIndex -Raw | ConvertFrom-Json -AsHashtable).objects
$outputPath = Join-Path $PSScriptRoot '../mods/CORE/mcl_sounds/sounds'

function Get-LocalAsset([string]$Key) {
    $hash = $objects[$Key].hash
    if ($hash -notmatch '^[a-f0-9]{40}$') { return }
    $source = Join-Path $AssetsDirectory ('objects/{0}/{1}' -f $hash.Substring(0, 2), $hash)
    if (!(Test-Path -LiteralPath $source -PathType Leaf)) { return }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA1).Hash -ne $hash) {
        throw "Minecraft asset failed the hash check: $Key"
    }
    return $source
}

$soundDefinitions = Get-LocalAsset 'minecraft/sounds.json'
if (!$soundDefinitions) { throw 'The asset cache is missing the sounds.json referenced by this index.' }
$sounds = Get-Content -LiteralPath $soundDefinitions -Raw | ConvertFrom-Json -AsHashtable
$manifest = [ordered]@{}
$copied = @{}
foreach ($event in $sounds.Keys) {
    if ($event -cnotmatch '^block\.(wooden_(trapdoor|door)|iron_(trapdoor|door)|copper_(trapdoor|door)|fence_gate)\.(open|close)$') { continue }

    $variants = foreach ($sound in $sounds[$event].sounds) {
        $name = if ($sound -is [string]) { $sound } else { $sound.name }
        $key = "minecraft/sounds/$name.ogg"
        if (!$copied.ContainsKey($key)) {
            $source = Get-LocalAsset $key
            if (!$source) {
                Write-Warning "Minecraft cache is missing $key"
                continue
            }
            $localName = 'mcl_sounds_java_door_' + $objects[$key].hash
            Copy-Item -LiteralPath $source -Destination (Join-Path $outputPath "$localName.ogg") -Force
            $copied[$key] = $localName
        }
        @{
            name = $copied[$key]
            gain = $sound.volume ?? 1.0
            pitch = $sound.pitch ?? 1.0
        }
    }
    if ($variants) { $manifest[$event] = @($variants) }
}

if (!$manifest.Count) { throw 'The asset cache contains none of the expected door or gate clips.' }
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputPath 'java_door_events.json') -Encoding utf8NoBOM
Write-Output "Imported $($copied.Count) clips for $($manifest.Count) door, trapdoor and gate events."
