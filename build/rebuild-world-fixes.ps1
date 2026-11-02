$ErrorActionPreference = 'Stop'
& ./native/scripts/build.ps1 -Arch x86_64 *> build/qwen-compat-x86-build.log
if ($LASTEXITCODE -ne 0) { throw 'x86_64 native build failed' }
& ./native/scripts/build.ps1 -Arch arm64-v8a *> build/qwen-compat-arm64-build.log
if ($LASTEXITCODE -ne 0) { throw 'arm64 native build failed' }
& ./scripts/build-hap.ps1 *> build/qwen-compat-hap-build.log
if ($LASTEXITCODE -ne 0) { throw 'HAP build failed' }
& ./build/package-reading-modes.ps1 *> build/qwen-compat-package.log
Write-Output 'DONE'
