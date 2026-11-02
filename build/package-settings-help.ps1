$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Location).Path
$hapSource = Join-Path $projectRoot 'entry/build/default/outputs/default/entry-default-signed.hap'
$simulatorPackage = Join-Path $projectRoot 'dist/HarmonyTavern-settings-help-simulator-20261102-signed.hap'
$phonePackage = Join-Path $projectRoot 'dist/HarmonyTavern-settings-help-arm64-20261102-signed.hap'
& ./scripts/build-hap.ps1 *> build/settings-help-final-build.log
if ($LASTEXITCODE -ne 0) { throw 'Final build failed' }
Copy-Item -LiteralPath $hapSource -Destination $simulatorPackage
$nativeSource = (Resolve-Path -LiteralPath 'entry/libs/x86_64/libttavern.so').Path
$stageDirectory = Join-Path $projectRoot ('build/settings-help-abi-stage-' + [guid]::NewGuid())
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build')) + [IO.Path]::DirectorySeparatorChar
$resolvedStage = [IO.Path]::GetFullPath($stageDirectory)
if (-not $resolvedStage.StartsWith($buildRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Stage outside build' }
$expectedNative = [IO.Path]::GetFullPath((Join-Path $projectRoot 'entry/libs/x86_64/libttavern.so'))
if ($nativeSource -ne $expectedNative) { throw 'Unexpected native library path' }
New-Item -ItemType Directory -Path $stageDirectory | Out-Null
$stagedLibrary = Join-Path $stageDirectory 'libttavern.so'
try {
  Move-Item -LiteralPath $nativeSource -Destination $stagedLibrary
  & ./scripts/build-hap.ps1 *> build/settings-help-arm64-build.log
  if ($LASTEXITCODE -ne 0) { throw 'Arm64 build failed' }
  Copy-Item -LiteralPath $hapSource -Destination $phonePackage
} finally {
  if (Test-Path -LiteralPath $stagedLibrary) { Move-Item -LiteralPath $stagedLibrary -Destination $nativeSource }
  Remove-Item -LiteralPath $stageDirectory
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($package in @($simulatorPackage, $phonePackage)) {
  $archive = [IO.Compression.ZipFile]::OpenRead($package)
  try {
    $architectures = @($archive.Entries | Where-Object FullName -Match '^libs/.*/libttavern.so$' | ForEach-Object FullName)
  } finally { $archive.Dispose() }
  if ($package -eq $phonePackage -and ($architectures.Count -ne 1 -or $architectures[0] -ne 'libs/arm64-v8a/libttavern.so')) {
    throw 'Unexpected phone ABIs'
  }
  $hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLower()
  [IO.File]::WriteAllText($package + '.sha256', $hash + '  ' + [IO.Path]::GetFileName($package) + [Environment]::NewLine)
  Write-Output ([IO.Path]::GetFileName($package) + ' ' + ($architectures -join ',') + ' ' + $hash)
}
