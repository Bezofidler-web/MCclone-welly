#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ClientJar,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\local\textures'),
    [string]$TitlePanorama,
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

function Write-TextureArchive([IO.Compression.ZipArchive]$Client, [string]$AssetPrefix, [string]$Path) {
    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    $count = 0
    try {
        foreach ($source in $Client.Entries) {
            if (-not $source.Name -or -not $source.FullName.StartsWith($AssetPrefix, [StringComparison]::Ordinal)) {
                continue
            }
            $relativePath = $source.FullName.Substring($AssetPrefix.Length)
            if ($relativePath -notmatch '^[a-z0-9_.-]+(?:/[a-z0-9_.-]+)*$' -or
                ($relativePath -split '/') -contains '..' -or ($relativePath -split '/') -contains '.') {
                throw "Invalid texture path in the Java JAR: $relativePath"
            }
            $target = $archive.CreateEntry($source.FullName)
            $inputStream = $source.Open()
            try {
                $outputStream = $target.Open()
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
            } finally {
                $inputStream.Dispose()
            }
            if ($source.Name.EndsWith('.png', [StringComparison]::Ordinal)) { $count++ }
        }
    } finally {
        $archive.Dispose()
    }
    return $count
}

function Write-BlockCrackStrip([IO.Compression.ZipArchive]$Client, [string]$AssetPrefix, [string]$Destination) {
    $target = 'crack_anylength.png'
    if (-not $IsWindows) {
        return @{ target = $target; reason = 'Windows is required to assemble the crack frames' }
    }

    $framePaths = @(0..9 | ForEach-Object { "block/destroy_stage_$_.png" })
    $frames = foreach ($framePath in $framePaths) {
        $entry = $Client.GetEntry($AssetPrefix + $framePath)
        if (-not $entry -or $entry.Length -gt 8KB) {
            return @{ target = $target; reason = 'missing or oversized block crack frame' }
        }
        $size = Get-PngSize ($entry.Open())
        if (-not $size -or $size.Width -ne 16 -or $size.Height -ne 16) {
            return @{ target = $target; reason = 'unexpected block crack frame size' }
        }
        $entry
    }

    Add-Type -AssemblyName System.Drawing.Common
    $strip = [Drawing.Bitmap]::new(16, 16 * $frames.Count)
    try {
        for ($i = 0; $i -lt $frames.Count; $i++) {
            $stream = $frames[$i].Open()
            try {
                $frame = [Drawing.Bitmap]::new($stream)
                try {
                    for ($y = 0; $y -lt $frame.Height; $y++) {
                        for ($x = 0; $x -lt $frame.Width; $x++) {
                            $strip.SetPixel($x, $i * $frame.Height + $y, $frame.GetPixel($x, $y))
                        }
                    }
                } finally {
                    $frame.Dispose()
                }
            } finally {
                $stream.Dispose()
            }
        }
        $strip.Save((Join-Path $Destination $target), [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $strip.Dispose()
    }
    return [ordered]@{ target = $target; source_frames = $framePaths; layout = 'vertical_strip' }
}

function Write-LiquidStrip([IO.Compression.ZipArchive]$Client, [IO.Compression.ZipArchiveEntry]$Entry,
    $SourceSize, $DestinationSize, [string]$Path) {
    if (-not $IsWindows -or $SourceSize.Width -notin 16, 32 -or
        $SourceSize.Height % $SourceSize.Width -ne 0 -or $DestinationSize.Height % $DestinationSize.Width -ne 0) {
        return $false
    }
    $metadata = $Client.GetEntry($Entry.FullName + '.mcmeta')
    if (-not $metadata -or $metadata.Length -gt 16KB) { return $false }
    $reader = [IO.StreamReader]::new($metadata.Open())
    try {
        $animation = ($reader.ReadToEnd() | ConvertFrom-Json).animation
    } catch [System.ArgumentException] {
        return $false
    } finally {
        $reader.Dispose()
    }
    if (-not $animation -or $animation.width -or $animation.height) { return $false }

    $sourceFrames = [int]($SourceSize.Height / $SourceSize.Width)
    $defaultTime = $animation.frametime ?? 1
    $sequence = $animation.frames ?? @(0..($sourceFrames - 1))
    $cycle = [Collections.Generic.List[int]]::new()
    foreach ($frame in $sequence) {
        $index = $frame
        $ticks = $defaultTime
        if ($frame -is [pscustomobject]) {
            $index = $frame.index
            $ticks = $frame.time ?? $defaultTime
        }
        if ($null -eq $index -or $index -lt 0 -or $index -ge $sourceFrames -or
            $ticks -lt 1 -or $cycle.Count + $ticks -gt 4096) { return $false }
        for ($tick = 0; $tick -lt $ticks; $tick++) { $cycle.Add([int]$index) }
    }
    if ($cycle.Count -eq 0) { return $false }

    # Keep the strip dimensions used by cauldrons, particle emitters and wield
    # textures. Sample the Java animation timeline across those frames.
    Add-Type -AssemblyName System.Drawing.Common
    $outputWidth = $DestinationSize.Width
    $outputFrames = [int]($DestinationSize.Height / $outputWidth)
    $tintWater = $Entry.Name -like 'water_*'
    $stream = $Entry.Open()
    try {
        $source = [Drawing.Bitmap]::new($stream)
        $strip = [Drawing.Bitmap]::new($outputWidth, $DestinationSize.Height)
        try {
            for ($i = 0; $i -lt $outputFrames; $i++) {
                $sourceFrame = $cycle[[int][Math]::Floor($i * $cycle.Count / $outputFrames)]
                for ($y = 0; $y -lt $outputWidth; $y++) {
                    $sourceY = $sourceFrame * $source.Width + [int][Math]::Floor($y * $source.Width / $outputWidth)
                    for ($x = 0; $x -lt $outputWidth; $x++) {
                        $sourceX = [int][Math]::Floor($x * $source.Width / $outputWidth)
                        $pixel = $source.GetPixel($sourceX, $sourceY)
                        if ($tintWater) {
                            # Java applies the normal biome tint to these grey water tiles.
                            $pixel = [Drawing.Color]::FromArgb($pixel.A,
                                [int]($pixel.R * 0x3F / 255), [int]($pixel.G * 0x76 / 255), [int]($pixel.B * 0xE4 / 255))
                        }
                        $strip.SetPixel($x, $i * $outputWidth + $y, $pixel)
                    }
                }
            }
            $output = [IO.File]::Open($Path, [IO.FileMode]::CreateNew)
            try {
                $strip.Save($output, [Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $output.Dispose()
            }
        } finally {
            $strip.Dispose()
            $source.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
    return $true
}

function Write-FoliageTexture([IO.Compression.ZipArchive]$Client, [IO.Compression.ZipArchiveEntry]$Entry,
    [string]$AssetPrefix, [string]$Path) {
    $palette = $Client.GetEntry($AssetPrefix + 'colormap/foliage.png')
    if (-not $IsWindows -or -not $palette -or $palette.Length -gt 1MB) { return $false }
    $size = Get-PngSize ($palette.Open())
    if (-not $size -or $size.Width -ne 256 -or $size.Height -ne 256) { return $false }

    Add-Type -AssemblyName System.Drawing.Common
    $paletteStream = $palette.Open()
    $sourceStream = $Entry.Open()
    try {
        $foliage = [Drawing.Bitmap]::new($paletteStream)
        try {
            # Bake the usual jungle tint into vines. Stock Mineclonia vines use
            # wallmounted orientation without a biome colour palette.
            $temperature = 0.95
            $humidity = 0.9 * $temperature
            $xTint = [int][Math]::Floor((1 - $temperature) * 255)
            $yTint = [int][Math]::Floor((1 - $humidity) * 255)
            $tint = $foliage.GetPixel($xTint, $yTint)
        } finally {
            $foliage.Dispose()
        }
        $source = [Drawing.Bitmap]::new($sourceStream)
        try {
            $texture = [Drawing.Bitmap]::new($source.Width, $source.Height)
            try {
                for ($y = 0; $y -lt $source.Height; $y++) {
                    for ($x = 0; $x -lt $source.Width; $x++) {
                        $pixel = $source.GetPixel($x, $y)
                        $colour = [Drawing.Color]::FromArgb($pixel.A,
                            [int][Math]::Floor($pixel.R * $tint.R / 255),
                            [int][Math]::Floor($pixel.G * $tint.G / 255),
                            [int][Math]::Floor($pixel.B * $tint.B / 255))
                        $texture.SetPixel($x, $y, $colour)
                    }
                }
                $texture.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $texture.Dispose()
            }
        } finally {
            $source.Dispose()
        }
    } finally {
        $sourceStream.Dispose()
        $paletteStream.Dispose()
    }
    return $true
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
    $archiveName = 'java-texture-library.zip'
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
            $source -notmatch '^assets/minecraft/textures/(block|item|entity|gui/sprites|particle)/[a-z0-9_./-]+\.png$') {
            continue
        }
        if (-not $candidates.ContainsKey($target)) { $candidates[$target] = [Collections.Generic.List[string]]::new() }
        if (-not $candidates[$target].Contains($source)) { $candidates[$target].Add($source) }
    }

    # The supplemental table takes precedence over older or ambiguous upstream rows.
    $explicit = @{}
    foreach ($row in Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'Java_Texture_Overrides.csv')) {
        if (-not $stock.ContainsKey($row.Target)) { throw "Unknown Mineclonia texture in supplemental mapping: $($row.Target)" }
        if ($row.Layout -and $row.Layout -notin 'vertical', 'proportional', 'scaled', 'liquid', 'foliage') {
            throw "Unknown texture layout for $($row.Target): $($row.Layout)"
        }
        $explicit[$row.Target] = $row.Layout
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
        $layout = $explicit[$target]
        foreach ($path in $paths) {
            $entry = $java.GetEntry($path)
            if (-not $entry -or $entry.Length -gt 8MB) { continue }
            $sourceSize = Get-PngSize ($entry.Open())
            if (-not $sourceSize -or -not $destinationSize) { $reason = 'invalid PNG'; continue }

            if ($layout -eq 'liquid') {
                if (Write-LiquidStrip $java $entry $sourceSize $destinationSize (Join-Path $staging $target)) {
                    $sourceEntry = $entry
                    break
                }
                $reason = 'unsupported liquid strip or animation metadata'
                continue
            }
            if ($layout -eq 'foliage') {
                if (Write-FoliageTexture $java $entry $assets (Join-Path $staging $target)) {
                    $sourceEntry = $entry
                    break
                }
                $reason = 'unavailable foliage tint'
                continue
            }
            $sameSize = $sourceSize.Width -eq $destinationSize.Width -and $sourceSize.Height -eq $destinationSize.Height
            $sameShape = [long]$sourceSize.Width * $destinationSize.Height -eq [long]$sourceSize.Height * $destinationSize.Width
            $frameStrip = $layout -eq 'vertical' -and $sourceSize.Width -eq $destinationSize.Width -and
                $sourceSize.Height % $sourceSize.Width -eq 0 -and $destinationSize.Height % $destinationSize.Width -eq 0 -and
                $java.GetEntry($path + '.mcmeta')
            $scaledSprite = $layout -eq 'scaled' -and $path -match '/gui/sprites/'
            if ($sameSize -or $frameStrip -or $scaledSprite -or
                ($sameShape -and ($path -match '/(block|item)/' -or $layout -eq 'proportional'))) {
                $sourceEntry = $entry
                break
            }
            $reason = 'layout or frame size differs'
        }
        if (-not $sourceEntry) {
            $skipped.Add([ordered]@{ target = $target; reason = $reason })
            continue
        }

        $sourcePath = $sourceEntry.FullName.Substring($assets.Length)
        if ($layout -eq 'liquid') {
            $imported.Add([ordered]@{ target = $target; source = $sourcePath; layout = 'liquid_strip' })
        } elseif ($layout -eq 'foliage') {
            $imported.Add([ordered]@{ target = $target; source = $sourcePath; layout = 'foliage_tint' })
        } else {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($sourceEntry, (Join-Path $staging $target))
            $imported.Add([ordered]@{ target = $target; source = $sourcePath })
        }
    }

    $crackStrip = Write-BlockCrackStrip $java $assets $staging
    if ($crackStrip.reason) {
        $skipped.Add($crackStrip)
    } else {
        $imported.Add($crackStrip)
    }
    foreach ($required in 'default_stone.png', 'default_dirt.png', 'default_tool_diamondpick.png') {
        if (-not [IO.File]::Exists((Join-Path $staging $required))) { throw "The JAR is missing a usable texture for $required." }
    }

    $panoramaName = 'mcl_menu_panorama.png'
    $panoramaSource = 'gui/title/background/panorama_0.png'
    if ($TitlePanorama) {
        $panoramaPath = (Resolve-Path -LiteralPath $TitlePanorama).Path
        $size = Get-PngSize ([IO.File]::OpenRead($panoramaPath))
        if (!$size -or $size.Width -lt 128 -or $size.Height -lt 128 -or
            $size.Width -gt 4096 -or $size.Height -gt 4096) {
            throw 'Select a PNG panorama between 128 and 4096 pixels on each side.'
        }
        [IO.File]::Copy($panoramaPath, (Join-Path $staging $panoramaName))
        $imported.Add([ordered]@{ target = $panoramaName; source = 'supplied title panorama' })
    } else {
        $entry = $java.GetEntry($assets + $panoramaSource)
        $size = if ($entry) { Get-PngSize ($entry.Open()) }
        if ($size -and $size.Width -ge 128 -and $size.Height -ge 128) {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $staging $panoramaName))
            $imported.Add([ordered]@{ target = $panoramaName; source = $panoramaSource })
        }
    }

    $pngCount = Write-TextureArchive $java $assets (Join-Path $staging $archiveName)
    @(
        "name = $packName"
        "title = Minecraft Java $version for Mineclonia"
        'description = Local texture overlay generated from your Minecraft Java client.'
    ) | Set-Content -LiteralPath (Join-Path $staging 'texture_pack.conf') -Encoding utf8NoBOM
    [ordered]@{ version = $version; textures = $imported; skipped = $skipped
        source_archive = $archiveName; source_png_count = $pngCount } |
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
    Write-Host "Imported $($imported.Count) playable overrides from Java $version. $($skipped.Count) mappings kept the game defaults."
    Write-Host "Archived all $pngCount Java textures and their metadata at $(Join-Path $pack $archiveName)"
    Write-Output $pack
} finally {
    $java.Dispose()
    if ($staging -and [IO.Directory]::Exists($staging)) {
        # This directory is created here and contains only the generated flat pack files.
        Get-ChildItem -LiteralPath $staging -File -Force | Remove-Item -Force
        Remove-Item -LiteralPath $staging
    }
}
