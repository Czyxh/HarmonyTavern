$ErrorActionPreference = 'Stop'
$projectRoot = (Get-Location).Path
$hap = 'entry/build/default/outputs/default/entry-default-signed.hap'
$simulator = 'dist/HarmonyTavern-reading-modes-simulator-20261102-signed.hap'
$phone = 'dist/HarmonyTavern-reading-modes-arm64-20261102-signed.hap'
Copy-Item -LiteralPath $hap -Destination $simulator -Force
$nativeSource = (Resolve-Path 'entry/libs/x86_64/libttavern.so').Path
$stage = Join-Path $projectRoot ('build/reading-modes-abi-stage-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $stage | Out-Null
$staged = Join-Path $stage 'libttavern.so'
try {
  Move-Item -LiteralPath $nativeSource -Destination $staged
  & ./scripts/build-hap.ps1 *> build/reading-modes-arm64-hap-build.log
  if ($LASTEXITCODE -ne 0) { throw 'arm64 HAP build failed' }
  Copy-Item -LiteralPath $hap -Destination $phone -Force
} finally {
  if (Test-Path -LiteralPath $staged) { Move-Item -LiteralPath $staged -Destination $nativeSource }
  Remove-Item -LiteralPath $stage -Force -Recurse
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($package in @($simulator, $phone)) {
  $hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLower()
  Set-Content -LiteralPath ($package + '.sha256') -NoNewline -Value ($hash + '  ' + [IO.Path]::GetFileName($package))
  $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $package))
  try { $abis = @($archive.Entries | Where-Object FullName -Match '^libs/.*/libttavern.so$' | ForEach-Object FullName) }
  finally { $archive.Dispose() }
  Write-Output ((Split-Path $package -Leaf) + ' ' + $hash + ' ' + ($abis -join ','))
}
