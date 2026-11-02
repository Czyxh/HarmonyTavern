param([string]$StudioRoot = 'C:\Program Files\Huawei\DevEco Studios\DevEco Studio')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $StudioRoot 'sdk\default\sdk-pkg.json'))) {
  throw 'API 26 DevEco SDK not found; pass -StudioRoot with the installed DevEco 26 directory.'
}
$sdkInfo = Get-Content -LiteralPath (Join-Path $StudioRoot 'sdk\default\sdk-pkg.json') -Raw | ConvertFrom-Json
if ([int]$sdkInfo.data.apiVersion -lt 26) { throw 'This project requires an API 26 build SDK.' }
$env:DEVECO_SDK_HOME = Join-Path $StudioRoot 'sdk'
$env:JAVA_HOME = Join-Path $StudioRoot 'jbr'
$env:PATH = (Join-Path $StudioRoot 'jbr\bin') + ';' + (Join-Path $StudioRoot 'tools\node') + ';' + $env:PATH
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  & (Join-Path $StudioRoot 'tools\hvigor\bin\hvigorw.bat') assembleHap --mode module -p product=default --no-daemon
  if ($LASTEXITCODE -ne 0) { throw "HAP build failed: $LASTEXITCODE" }
} finally { Pop-Location }
