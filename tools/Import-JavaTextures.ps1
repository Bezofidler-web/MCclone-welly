#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ClientJar,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\local\textures'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-PngSize([IO.Stream]$Stream) {
    try {
        $header = [byte[]]::new(24)
        $read = 0
        while ($read -lt $header.Length) {
            $count = $Stream.Read($header, $read, $header.Length - $read)
            if ($count -eq 0) { return }
            $read += $count
        }
        if ([BitConverter]::ToString($header, 0, 8) -ne '89-50-4E-47-0D-0A-1A-0A' -or
            [Text.Encoding]::ASCII.GetString($header, 12, 4) -ne 'IHDR') { return }

        $width = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($header, 16))
        $height = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($header, 20))
        if ($width -gt 0 -and $height -gt 0) {
            [pscustomobject]@{ Width = $width; Height = $height }
        }
    } finally {
        $Stream.Dispose()
    }
}

$game = Split-Path $PSScriptRoot -Parent
$assets = 'assets/minecraft/textures/'
$jarPath = (Resolve-Path -LiteralPath $ClientJar).Path
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$java = [IO.Compression.ZipFile]::OpenRead($jarPath)
$staging = $null
try {
    $versionEntry = $java.GetEntry('version.json')
    if (-not $versionEntry -or -not $java.GetEntry($assets + 'block/stone.png')) {
        throw 'Select a Minecraft Java Edition client JAR from the launcher versions folder.'
    }
    $reader = [IO.StreamReader]::new($versionEntry.Open())
    try { $version = ($reader.ReadToEnd() | ConvertFrom-Json).id } finally { $reader.Dispose() }
    if ($version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,50}$') { throw 'Invalid Java version ID in the JAR.' }

    $packName = 'mineclonia-java-' + $version.ToLowerInvariant()
    $pack = Join-Path $outputPath $packName
    $markerName = 'mineclonia-java-import.json'
    if (Test-Path -LiteralPath $pack) {
        $existing = Get-Item -LiteralPath $pack -Force
        if (-not $Force -or -not $existing.PSIsContainer -or
            ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            -not (Test-Path -LiteralPath (Join-Path $pack $markerName) -PathType Leaf)) {
            throw "The pack folder already exists. Use a different output folder or -Force for a pack this script made. $pack"
        }
    }

    $stock = @{}
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $game 'mods') -Recurse -File -Filter '*.png') {
        $stock[$file.Name] = $file.FullName
    }

    $candidates = @{}
    foreach ($row in Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'Conversion_Table.csv')) {
        if ($row.'Blacklisted?' -eq 'y' -or $row.xs -or $row.ys -or $row.xl -or $row.yl -or $row.xt -or $row.yt) {
            continue
        }
        $source = $row.'Source path'.TrimStart('/') + '/' + $row.'Source file'
        $target = $row.'Target file'
        if (-not $stock.ContainsKey($target) -or
            $source -notmatch '^assets/minecraft/textures/(block|item|entity|gui/sprites)/[a-z0-9_./-]+\.png$') {
            continue
        }
        if (-not $candidates.ContainsKey($target)) { $candidates[$target] = [Collections.Generic.List[string]]::new() }
        if (-not $candidates[$target].Contains($source)) { $candidates[$target].Add($source) }
    }

    # The supplemental table takes precedence over older or ambiguous upstream rows.
    $explicit = @{}
    foreach ($row in Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'Java_Texture_Overrides.csv')) {
        if (-not $stock.ContainsKey($row.Target)) { throw "Unknown Mineclonia texture in supplemental mapping: $($row.Target)" }
        $explicit[$row.Target] = $true
        $candidates[$row.Target] = @($row.JavaPaths.Split('|') | ForEach-Object { $assets + $_ })
    }

    [void][IO.Directory]::CreateDirectory($outputPath)
    $staging = Join-Path $outputPath ('.java-textures-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($staging)
    $imported = [Collections.Generic.List[object]]::new()
    $skipped = [Collections.Generic.List[object]]::new()
    foreach ($target in ($candidates.Keys | Sort-Object)) {
        $paths = $candidates[$target]
        if ($paths.Count -gt 1 -and -not $explicit.ContainsKey($target)) {
            $skipped.Add([ordered]@{ target = $target; reason = 'ambiguous mapping' })
            continue
        }

        $destinationSize = Get-PngSize ([IO.File]::OpenRead($stock[$target]))
        $sourceEntry = $null
        $reason = 'absent from this Java version'
        foreach ($path in $paths) {
            $entry = $java.GetEntry($path)
            if (-not $entry -or $entry.Length -gt 8MB) { continue }
            $sourceSize = Get-PngSize ($entry.Open())
            if (-not $sourceSize -or -not $destinationSize) { $reason = 'invalid PNG'; continue }

            $sameSize = $sourceSize.Width -eq $destinationSize.Width -and $sourceSize.Height -eq $destinationSize.Height
            $sameShape = [long]$sourceSize.Width * $destinationSize.Height -eq [long]$sourceSize.Height * $destinationSize.Width
            if ($sameSize -or ($sameShape -and $path -match '/(block|item)/')) {
                $sourceEntry = $entry
                break
            }
            $reason = 'layout or frame size differs'
        }
        if (-not $sourceEntry) {
            $skipped.Add([ordered]@{ target = $target; reason = $reason })
            continue
        }

        [IO.Compression.ZipFileExtensions]::ExtractToFile($sourceEntry, (Join-Path $staging $target))
        $imported.Add([ordered]@{ target = $target; source = $sourceEntry.FullName.Substring($assets.Length) })
    }

    foreach ($required in 'default_stone.png', 'default_dirt.png', 'default_tool_diamondpick.png') {
        if (-not [IO.File]::Exists((Join-Path $staging $required))) { throw "The JAR is missing a usable texture for $required." }
    }
    @(
        "name = $packName"
        "title = Minecraft Java $version for Mineclonia"
        'description = Local texture overlay generated from your Minecraft Java client.'
    ) | Set-Content -LiteralPath (Join-Path $staging 'texture_pack.conf') -Encoding utf8NoBOM
    [ordered]@{ version = $version; textures = $imported; skipped = $skipped } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $staging $markerName) -Encoding utf8NoBOM

    if ([IO.Directory]::Exists($pack)) {
        $backup = $pack + '.previous-' + [Guid]::NewGuid().ToString('N')
        [IO.Directory]::Move($pack, $backup)
        try {
            [IO.Directory]::Move($staging, $pack)
        } catch {
            [IO.Directory]::Move($backup, $pack)
            throw
        }
        Write-Host "Previous pack kept at $backup"
    } else {
        [IO.Directory]::Move($staging, $pack)
    }
    $staging = $null
    Write-Host "Imported $($imported.Count) textures from Java $version. $($skipped.Count) mappings kept the game defaults."
    Write-Output $pack
} finally {
    $java.Dispose()
    if ($staging -and [IO.Directory]::Exists($staging)) {
        # This directory is created here and contains only the generated flat pack files.
        Get-ChildItem -LiteralPath $staging -File -Force | Remove-Item -Force
        Remove-Item -LiteralPath $staging
    }
}
