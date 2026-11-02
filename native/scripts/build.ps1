# Build the NAPI .so and copy it into the HarmonyOS project at entry/libs/<abi>/
# Usage: powershell -File native\scripts\build.ps1 [-Arch x86_64|arm64-v8a] [-Debug]
# Default: x86_64 (local HarmonyOS 6.0.2 x86 emulator image); devices use -Arch arm64-v8a
param(
  [ValidateSet('x86_64', 'arm64-v8a')]
  [string]$Arch = 'x86_64',
  [switch]$Debug
)
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$nativeRoot = Split-Path -Parent $scriptDir          # ...\native
$repoRoot   = Split-Path -Parent $nativeRoot         # ...\HarmonyTavern

# cargo installed by rustup is not on PATH by default
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
if (Test-Path (Join-Path $cargoBin 'cargo.exe')) {
  $env:PATH = "$cargoBin;$env:PATH"
}

. (Join-Path $scriptDir 'env-ohos.ps1') -Arch $Arch

$target   = $env:TARGET_TRIPLE
$profile  = if ($Debug) { 'debug' } else { 'release' }
$cargoArgs = @('build', '--target', $target, '-p', 'ttavern')
if (-not $Debug) { $cargoArgs += '--release' }

Push-Location $nativeRoot
try {
  cargo @cargoArgs
  if ($LASTEXITCODE -ne 0) { throw "cargo build failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}

$so = Join-Path $nativeRoot "target\$target\$profile\libttavern.so"
if (-not (Test-Path $so)) { throw "expected library not produced: $so" }

$destDir = Join-Path $repoRoot "entry\libs\$env:TT_ABI"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item $so (Join-Path $destDir 'libttavern.so') -Force

Write-Host "OK: $so"
Write-Host "  -> $destDir\libttavern.so (packed into HAP by hvigor)"
