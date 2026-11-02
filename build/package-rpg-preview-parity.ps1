$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Location).Path
$hapSource = Join-Path $projectRoot 'entry/build/default/outputs/default/entry-default-signed.hap'
$simulatorPackage = Join-Path $projectRoot 'dist/HarmonyTavern-rpg-preview-parity-simulator-20261102-signed.hap'
$phonePackage = Join-Path $projectRoot 'dist/HarmonyTavern-rpg-preview-parity-arm64-20261102-signed.hap'
foreach ($architecture in @('x86_64', 'arm64-v8a')) {
  $target = if ($architecture -eq 'x86_64') { 'x86_64-unknown-linux-ohos' } else { 'aarch64-unknown-linux-ohos' }
  $compiled = Join-Path $projectRoot "native/target/$target/release/libttavern.so"
  $packed = Join-Path $projectRoot "entry/libs/$architecture/libttavern.so"
  if ((Get-FileHash $compiled).Hash -ne (Get-FileHash $packed).Hash) { throw "Stale $architecture library" }
}
& ./scripts/build-hap.ps1 *> build/rpg-preview-parity-final-build.log
if ($LASTEXITCODE -ne 0) { throw 'Final build failed' }
Copy-Item -LiteralPath $hapSource -Destination $simulatorPackage
$nativeSource = (Resolve-Path -LiteralPath 'entry/libs/x86_64/libttavern.so').Path
$stageDirectory = Join-Path $projectRoot ('build/rpg-preview-parity-abi-stage-' + [guid]::NewGuid())
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build')) + [IO.Path]::DirectorySeparatorChar
if (-not [IO.Path]::GetFullPath($stageDirectory).StartsWith($buildRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Stage outside build' }
if ($nativeSource -ne [IO.Path]::GetFullPath((Join-Path $projectRoot 'entry/libs/x86_64/libttavern.so'))) { throw 'Unexpected library path' }
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$stagedLibrary = Join-Path $stageDirectory 'libttavern.so'
try {
  Move-Item -LiteralPath $nativeSource -Destination $stagedLibrary
  & ./scripts/build-hap.ps1 *> build/rpg-preview-parity-arm64-build.log
  if ($LASTEXITCODE -ne 0) { throw 'Arm64 build failed' }
  Copy-Item -LiteralPath $hapSource -Destination $phonePackage
} finally {
  if (Test-Path -LiteralPath $stagedLibrary) { Move-Item -LiteralPath $stagedLibrary -Destination $nativeSource }
  Remove-Item -LiteralPath $stageDirectory
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($package in @($simulatorPackage, $phonePackage)) {
  $archive = [IO.Compression.ZipFile]::OpenRead($package)
  try { $architectures = @($archive.Entries | Where-Object FullName -Match '^libs/.*/libttavern.so$' | ForEach-Object FullName) }
  finally { $archive.Dispose() }
  if ($package -eq $phonePackage -and ($architectures.Count -ne 1 -or $architectures[0] -ne 'libs/arm64-v8a/libttavern.so')) { throw 'Unexpected phone ABIs' }
  if ($package -eq $simulatorPackage -and $architectures -notcontains 'libs/x86_64/libttavern.so') { throw 'Missing simulator ABI' }
  $hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText($package + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($package) + [Environment]::NewLine)
  Write-Output ([IO.Path]::GetFileName($package) + ' ' + ($architectures -join ',') + ' ' + $hash)
}


