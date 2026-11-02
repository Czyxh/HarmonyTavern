# HarmonyTavern artifact report
#
# Purpose: every phase report quotes numbers (so size, HAP size, command count,
# service count, media count). Those numbers were previously retyped by hand,
# which drifts. This script prints them from the actual files.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\native\scripts\report.ps1
#
# NOTE: keep this file pure ASCII. A .ps1 containing non-ASCII gets decoded with
# the console code page and the text turns into mojibake (this bit us 4 times,
# including once inside this very script where a non-ASCII docs filename made a
# whole section silently print nothing).
#
# UNITS: print exact bytes first, then MiB (bytes / 1048576, the unit Windows
# Explorer and DevEco show). Decimal MB and MiB differ by 4.8% and mixing them
# makes cross-checks with Explorer fail.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $root 'entry'))) {
    $root = (Get-Location).Path
}

function Format-Size([long]$bytes) {
    $mib = $bytes / 1048576
    return ('{0,10:N0} B = {1,7:N2} MiB' -f $bytes, $mib)
}

Write-Output ''
Write-Output '================ HarmonyTavern artifact report ================'
Write-Output ("root: {0}" -f $root)
Write-Output ''

# ---------- 1. native libraries ----------
Write-Output '[1] libttavern.so (one per ABI; both get packed into the HAP)'
$libRoot = Join-Path $root 'entry/libs'
$totalSo = 0
foreach ($abi in @('x86_64', 'arm64-v8a')) {
    $p = Join-Path $libRoot "$abi/libttavern.so"
    if (Test-Path $p) {
        $f = Get-Item $p
        $totalSo += $f.Length
        Write-Output ("    {0,-10} {1}  {2}" -f $abi, (Format-Size $f.Length), $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    } else {
        Write-Output ("    {0,-10} MISSING - run native/scripts/build.ps1" -f $abi)
    }
}
Write-Output ("    {0,-10} {1}" -f 'total', (Format-Size $totalSo))
Write-Output ''

# ---------- 2. HAP ----------
Write-Output '[2] HAP'
$outDir = Join-Path $root 'entry/build/default/outputs/default'
if (Test-Path $outDir) {
    $haps = @(Get-ChildItem $outDir -Filter *.hap -ErrorAction SilentlyContinue)
    if ($haps.Count -gt 0) {
        foreach ($h in $haps) {
            Write-Output ("    {0,-30} {1}  {2}" -f $h.Name, (Format-Size $h.Length), $h.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        }
    } else {
        Write-Output '    no .hap yet - run hvigorw assembleHap'
    }
} else {
    Write-Output '    no output dir yet - run hvigorw assembleHap'
}
Write-Output ''

# ---------- 3. NAPI surface ----------
Write-Output '[3] NAPI bridge'
$libRs = Join-Path $root 'native/crates/ttavern/src/lib.rs'
if (Test-Path $libRs) {
    # must match both `pub fn` and `pub async fn`; matching only `pub fn` silently
    # undercounts (6 exports reported as 3).
    $all = (Select-String -Path $libRs -Pattern '^\s*pub (async )?fn (\w+)').Count
    $business = (Select-String -Path $libRs -Pattern '^\s*pub (async )?fn (\w+)' | Where-Object { $_.Matches[0].Groups[2].Value -notin @('hello', 'add') }).Count
    Write-Output ("    exported fns in lib.rs : {0}  (of which business: {1}, demo: hello/add)" -f $all, $business)
}

$dispatch = Join-Path $root 'native/crates/ttavern/src/presentation/dispatch.rs'
if (Test-Path $dispatch) {
    $routes = (Select-String -Path $dispatch -Pattern 'commands::\w+::\w+\(').Count
    Write-Output ("    dispatch routes        : {0}" -f $routes)
    $names = Select-String -Path $dispatch -Pattern '"([a-z0-9_]+)"\s*=>' | ForEach-Object { $_.Matches[0].Groups[1].Value }
    if ($names.Count -gt 0) {
        Write-Output ("    distinct command names : {0}" -f ($names | Sort-Object -Unique).Count)
    }
}

$services = Join-Path $root 'native/crates/ttavern/src/host/services.rs'
if (Test-Path $services) {
    $m = Select-String -Path $services -Pattern 'pub const COUNT: usize = (\d+)'
    if ($m) { Write-Output ("    AppServices::COUNT      : {0}" -f $m.Matches[0].Groups[1].Value) }
}

$cmdsDir = Join-Path $root 'native/crates/ttavern/src/presentation/commands'
if (Test-Path $cmdsDir) {
    $files = @(Get-ChildItem $cmdsDir -Filter *.rs | Where-Object { $_.Name -ne 'mod.rs' })
    Write-Output ("    command modules ({0})   : {1}" -f $files.Count, (($files | ForEach-Object { $_.BaseName }) -join ', '))
}
Write-Output ''

# ---------- 4. bundled media (rawfile) ----------
Write-Output '[4] bundled media (rawfile -> extracted to <filesDir>/.bundled-media)'
$mediaRoot = Join-Path $root 'entry/src/main/resources/rawfile/default'
if (Test-Path $mediaRoot) {
    $files = @(Get-ChildItem $mediaRoot -Recurse -File)
    $sum = ($files | Measure-Object Length -Sum).Sum
    Write-Output ("    files                  : {0}" -f $files.Count)
    Write-Output ("    bytes                  : {0}" -f (Format-Size $sum))
} else {
    Write-Output '    rawfile media not synced - run native/scripts/sync-rawfile-media.ps1'
}
$manifest = Join-Path $root 'entry/src/main/ets/backend/MediaManifest.ets'
if (Test-Path $manifest) {
    $m = Select-String -Path $manifest -Pattern 'MEDIA_FILE_COUNT: number = (\d+)'
    if ($m) { Write-Output ("    manifest declares      : {0} files (must equal the count above)" -f $m.Matches[0].Groups[1].Value) }
}
Write-Output ''

# ---------- 5. ArkTS sources ----------
Write-Output '[5] ArkTS sources'
$ets = Join-Path $root 'entry/src/main/ets'
if (Test-Path $ets) {
    $files = @(Get-ChildItem $ets -Recurse -Filter *.ets)
    $lines = 0
    foreach ($f in $files) { $lines += (Get-Content $f.FullName).Count }
    Write-Output ("    .ets files             : {0}" -f $files.Count)
    Write-Output ("    .ets lines             : {0}" -f $lines)
    foreach ($f in $files) {
        $rel = $f.FullName.Replace($ets + '\', '').Replace('\', '/')
        Write-Output ("      {0,-44} {1,5} lines" -f $rel, (Get-Content $f.FullName).Count)
    }
}
Write-Output ''

# ---------- 6. docs (glob, never a hard-coded non-ASCII name) ----------
Write-Output '[6] docs'
$docsDir = Join-Path $root 'docs'
if (Test-Path $docsDir) {
    $md = @(Get-ChildItem $docsDir -Filter *.md)
    if ($md.Count -gt 0) {
        foreach ($d in $md) {
            Write-Output ("    {0,-30} {1} lines, {2}" -f $d.Name, (Get-Content $d.FullName -Encoding UTF8).Count, (Format-Size $d.Length))
        }
    } else {
        Write-Output '    no .md in docs'
    }
} else {
    Write-Output '    no docs dir'
}
Write-Output ''

# ---------- 7. cargo workspace ----------
Write-Output '[7] cargo workspace'
$cargo = Join-Path $root 'native/Cargo.toml'
if (Test-Path $cargo) {
    $members = (Select-String -Path $cargo -Pattern '^\s*"crates/').Count
    Write-Output ("    members                : {0}" -f $members)
}
Write-Output ''
Write-Output '==============================================================='
