#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EngineZip,
    [Parameter(Mandatory)][string]$Output
)
$ErrorActionPreference = 'Stop'
$game = Split-Path $PSScriptRoot -Parent
$target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
if ([IO.File]::Exists($target)) { throw "Choose a new package filename: $target" }
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $EngineZip).Path)
$scratch = $target + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
$files = @(git -c core.quotepath=false -C $game ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { $archive.Dispose(); throw 'Could not list the game source checkout.' }
$level = [IO.Compression.CompressionLevel]::Fastest
try {
    $engine = @($archive.Entries | Where-Object { $_.FullName -cmatch '^[^/]+/bin/luanti\.exe$' })
    if ($engine.Count -ne 1) { throw 'Select an original Luanti Windows release ZIP.' }
    $prefix = $engine[0].FullName.Split('/')[0] + '/'
    $package = [IO.Compression.ZipFile]::Open($scratch, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($path in $files) {
            # Personal worlds, credentials, imports and client profiles live under local.
            $file = [IO.Path]::Combine($game, $path)
            if ($path -match '^(?:\.|local/)' -or ![IO.File]::Exists($file)) { continue }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($package, $file, "mineclonia/$path", $level)
        }
        foreach ($entry in $archive.Entries) {
            if (!$entry.Name -or !$entry.FullName.StartsWith($prefix, [StringComparison]::Ordinal)) { continue }
            $relative = $entry.FullName.Substring($prefix.Length)
            if ($relative -match '(?:^|/)\.\.(?:/|$)|[\\:]|^/') { throw "Invalid release entry." }
            # Use the original distribution. Never collect files from a played installation.
            if ($relative -match '^(worlds|cache|mod_data|clientmods|games)/|^(debug\.txt|minetest\.conf)$') { continue }
            $destination = $package.CreateEntry('mineclonia/local/luanti/' + $relative, $level).Open()
            $source = $entry.Open()
            try { $source.CopyTo($destination) } finally { $source.Dispose(); $destination.Dispose() }
        }
    } finally { $package.Dispose() }
    [IO.File]::Move($scratch, $target)
} finally {
    $archive.Dispose()
    if ([IO.File]::Exists($scratch)) { [IO.File]::Delete($scratch) }
}
Get-Item -LiteralPath $target
