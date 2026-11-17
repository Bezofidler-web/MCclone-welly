#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot '../../.friends-work/luanti-client-build/luanti-5.18.0'),
    [string]$Toolchain = (Join-Path $PSScriptRoot '../../.friends-work/luanti-client-build/msys64/clang64'),
    [string]$CMakeExe,
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../local/java-client-build'),
    [string]$Destination = (Join-Path $PSScriptRoot '../local/java-client'),
    [ValidateRange(1, 64)][int]$Jobs = 6
)

$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$compilerRoot = (Resolve-Path -LiteralPath $Toolchain).Path
$buildPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BuildDirectory)
$installPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
$toolsBin = Join-Path $compilerRoot 'bin'
$cmake = if ($CMakeExe) { (Resolve-Path -LiteralPath $CMakeExe).Path } else { Join-Path $toolsBin 'cmake.exe' }
$ninja = Join-Path $toolsBin 'ninja.exe'
$objdump = Join-Path $toolsBin 'llvm-objdump.exe'
$game = Split-Path $PSScriptRoot -Parent
if (!(Test-Path -LiteralPath (Join-Path $sourcePath 'src/client/java_debug.cpp'))) {
    throw 'Give -Source a Luanti 5.18.0 source directory with the Mineclonia Java client patch applied.'
}
foreach ($tool in $cmake, $ninja, $objdump) {
    if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Required CLANG64 tool missing: $tool" }
}

$previousPath = $env:PATH
$env:PATH = "$toolsBin;$previousPath"
try {
    & $cmake -S $sourcePath -B $buildPath -G Ninja `
        "-DCMAKE_MAKE_PROGRAM=$ninja" "-DCMAKE_PREFIX_PATH=$compilerRoot" `
        "-DCMAKE_C_COMPILER=$(Join-Path $toolsBin 'clang.exe')" `
        "-DCMAKE_CXX_COMPILER=$(Join-Path $toolsBin 'clang++.exe')" `
        '-DCMAKE_BUILD_TYPE=Release' '-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG' `
        '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' `
        '-DCMAKE_CXX_FLAGS_RELEASE=-O2 -DNDEBUG' '-DVERSION_EXTRA=mineclonia-java26.3' `
        '-DRUN_IN_PLACE=ON' '-DBUILD_CLIENT=ON' '-DBUILD_SERVER=OFF' `
        '-DENABLE_LTO=OFF' '-DBUILD_UNITTESTS=OFF' '-DENABLE_CURSES=OFF' `
        '-DENABLE_POSTGRESQL=OFF' '-DENABLE_REDIS=OFF' '-DREQUIRE_LUAJIT=ON'
    if ($LASTEXITCODE) { throw 'Luanti configuration failed.' }

    & $cmake --build $buildPath --parallel $Jobs
    if ($LASTEXITCODE) { throw 'Luanti compilation failed.' }
    & $cmake --install $buildPath --prefix $installPath
    if ($LASTEXITCODE) { throw 'Luanti installation failed.' }

    $destinationBin = Join-Path $installPath 'bin'
    $exe = Join-Path $destinationBin 'luanti.exe'
    # Follow the PE import table so the package runs without the build tools on PATH.
    $pending = [Collections.Generic.Queue[string]]::new()
    $copied = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pending.Enqueue($exe)
    while ($pending.Count) {
        $file = $pending.Dequeue()
        $imports = & $objdump -p $file
        if ($LASTEXITCODE) { throw "Could not list dependencies of $file" }
        foreach ($line in $imports) {
            if ($line -notmatch '^\s*DLL Name:\s*([\w.+-]+\.dll)\s*$') { continue }
            $dll = $Matches[1]
            $library = Join-Path $toolsBin $dll
            if ((Test-Path -LiteralPath $library -PathType Leaf) -and $copied.Add($dll)) {
                $copy = Join-Path $destinationBin $dll
                Copy-Item -LiteralPath $library -Destination $copy -Force
                $pending.Enqueue($copy)
            }
        }
    }

    Copy-Item -LiteralPath (Join-Path $game 'menu/overlay.png') -Destination `
        (Join-Path $installPath 'textures/base/pack/mcl_java_loading_panorama.png') -Force
    Write-Output $exe
} finally {
    $env:PATH = $previousPath
}
