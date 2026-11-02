# Run the reused Rust layer's own test suite on the host machine.
#
# Why this exists: the port keeps tt-domain / tt-contracts / tt-ports /
# tt-application / tt-adapter-* verbatim from upstream, and upstream ships ~1,100
# unit tests inside those crates. "It compiles for OHOS" says nothing about whether
# the behaviour survived the port; running the suite does. These tests need no
# HarmonyOS device and take a few seconds once compiled.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\native\scripts\test.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\native\scripts\test.ps1 -Package tt-application
#
# NOTE: keep this file pure ASCII (a non-ASCII .ps1 gets decoded with the console
# code page and turns into mojibake - this has bitten this project several times).
param(
    [string]$Package = ''
)

$ErrorActionPreference = 'Stop'
$nativeRoot = Split-Path -Parent $PSScriptRoot
Set-Location $nativeRoot

# cargo installed by rustup is not on PATH by default.
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (Test-Path (Join-Path $cargoBin 'cargo.exe')) {
    $env:PATH = "$cargoBin;$env:PATH"
}

$env:CARGO_TERM_COLOR = 'never'
$log = Join-Path $nativeRoot 'test-all.log'

# Native commands write warnings to stderr, and with $ErrorActionPreference='Stop'
# any stderr write is promoted to a terminating error (NativeCommandError) - that
# aborted this script on a mere "field is never read" warning. Redirect all streams
# to the log file and relax the preference for the duration of the call.
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
if ($Package -ne '') {
    Write-Host "== cargo test -p $Package =="
    cargo test -p $Package --no-fail-fast *> $log
} else {
    Write-Host '== cargo test --workspace =='
    cargo test --workspace --no-fail-fast *> $log
}
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $previousPreference
Write-Host "cargo exit code: $exitCode  (log: $log)"

$lines = Get-Content $log
$current = ''
$rows = @()
foreach ($line in $lines) {
    if ($line -match '^\s+Running unittests .*?deps\\(\w+)-[0-9a-f]+\.exe') {
        $current = $Matches[1]
    } elseif ($line -match '^\s+Running tests\\') {
        $current = 'integration'
    } elseif ($line -match '^test result: ok\. (\d+) passed') {
        if ([int]$Matches[1] -gt 0) {
            $rows += [pscustomobject]@{ Crate = $current; Count = [int]$Matches[1] }
        }
    }
}

Write-Host ''
Write-Host 'crate                              tests'
Write-Host '---------------------------------- -----'
foreach ($group in ($rows | Group-Object Crate | Sort-Object { ($_.Group | Measure-Object Count -Sum).Sum } -Descending)) {
    $sum = ($group.Group | Measure-Object Count -Sum).Sum
    Write-Host ('{0,-34} {1,5}' -f $group.Name, $sum)
}
Write-Host ('{0,-34} {1,5}' -f 'TOTAL', (($rows | Measure-Object Count -Sum).Sum))

$failed = 0
foreach ($line in $lines) {
    if ($line -match '^test result: FAILED\. \d+ passed; (\d+) failed') {
        $failed += [int]$Matches[1]
    }
}
if ($failed -gt 0) {
    Write-Host ''
    Write-Host "FAILED: $failed test(s) - see $log"
    exit 1
}
if ($lines | Select-String -Pattern 'could not compile') {
    Write-Host ''
    Write-Host "BUILD FAILED - see $log"
    exit 1
}
Write-Host ''
Write-Host 'All tests passed.'
