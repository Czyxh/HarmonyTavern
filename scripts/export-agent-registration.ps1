$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'entry/src/main/resources/base/profile/agent_config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$card = $config.agentCards[0]
$exportDirectory = Join-Path $projectRoot 'dist/agent-registration'
New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
Copy-Item -LiteralPath $configPath -Destination (Join-Path $exportDirectory 'agent_config.json')
$card | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $exportDirectory 'AgentCard.json') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $projectRoot 'entry/src/main/resources/rawfile/agent/harmonytavern.png') -Destination (Join-Path $exportDirectory 'harmonytavern.png')
@"
Bundle name: $($card.appInfo.bundleName)
Module name: $($card.appInfo.moduleName)
Agent extension ability name: $($card.appInfo.abilityName)
Local AgentCard agentId: $($card.agentId)
Source profile: $configPath

agent_config.json is the SDK profile wrapper containing agentCards.
AgentCard.json is the single-card object exported from that same profile.
Choose the format requested by the platform. No platform-issued ID or approval is implied.
The iconUrl points to a packaged local raw resource. harmonytavern.png is included for a separate icon upload if required.
The A2A server currently requires API 26. Platform registration, account access and real Xiaoyi end-to-end testing remain pending.
"@ | Set-Content -LiteralPath (Join-Path $exportDirectory 'registration-fields.txt') -Encoding utf8
Write-Output $exportDirectory
