$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Location).Path
$hapSource = Join-Path $projectRoot 'entry/build/default/outputs/default/entry-default-signed.hap'
$simulatorPackage = Join-Path $projectRoot 'dist/HarmonyTavern-usage-nav-simulator-20261102-signed.hap'
$phonePackage = Join-Path $projectRoot 'dist/HarmonyTavern-usage-nav-arm64-20261102-signed.hap'
& ./scripts/build-hap.ps1 *> usage-nav-package-build.log
if ($LASTEXITCODE -ne 0) { throw 'Final build failed' }
Copy-Item -LiteralPath $hapSource -Destination $simulatorPackage
$nativeSource = (Resolve-Path -LiteralPath 'entry/libs/x86_64/libttavern.so').Path
$stageDirectory = Join-Path $projectRoot ('build/usage-abi-stage-' + [guid]::NewGuid())
if (-not $stageDirectory.StartsWith((Join-Path $projectRoot 'build/'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Stage outside build' }
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$stagedLibrary = Join-Path $stageDirectory 'libttavern.so'
try {
  Move-Item -LiteralPath $nativeSource -Destination $stagedLibrary
  & ./scripts/build-hap.ps1 *> usage-nav-arm64-build.log
  if ($LASTEXITCODE -ne 0) { throw 'Arm64 build failed' }
  Copy-Item -LiteralPath $hapSource -Destination $phonePackage
} finally {
  if (Test-Path -LiteralPath $stagedLibrary) { Move-Item -LiteralPath $stagedLibrary -Destination $nativeSource }
  Remove-Item -LiteralPath $stageDirectory
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($package in @($simulatorPackage, $phonePackage)) {
  $zip = [IO.Compression.ZipFile]::OpenRead($package)
  try { $abis = @($zip.Entries | Where-Object FullName -Match '^libs/.*/libttavern.so$' | ForEach-Object FullName) } finally { $zip.Dispose() }
  if ($package -eq $phonePackage -and ($abis.Count -ne 1 -or $abis[0] -ne 'libs/arm64-v8a/libttavern.so')) { throw 'Unexpected phone ABIs' }
  $hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText($package + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($package) + [Environment]::NewLine)
  Write-Output ([IO.Path]::GetFileName($package) + ' ' + ($abis -join ',') + ' ' + $hash)
}



