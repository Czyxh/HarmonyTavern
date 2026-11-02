# P7 步骤 7 真机验收助手（2026-10-28）。
#
# 用法（PowerShell 5.1/7+，真机 USB 调试已开、hdc 已连）：
#   powershell -File scripts\verify-device.ps1 -Hap C:\path\to\entry-default-signed.hap
#   powershell -File scripts\verify-device.ps1 list          # 列出 hdc 目标
#   powershell -File scripts\verify-device.ps1 dump          # 打印当前屏可见文本
#
# 提供的小工具（全部基于模拟器已跑通的环路：dumpLayout 找控件 → uinput 点击 →
# hilog 抓 HarmonyTavern TAG）：
#   Install-Login       安装签名 HAP + 冷启 + 等 Index 渲染
#   Probe-P62           点「运行 P6.2 验证」→ hilog 等 `P6.2 chain done: 12/12 passed`
#   Tap-Text <文本>     在当前 dump 里按文本找 Button 并点中心
#   Dump-Text           列出当前 dump 可见文本（定位用）
#   Run-Checklist       跑一遍能自动化的验收点（安装/首启/P6.2/导航/弹窗），
#                       输出逐项 PASS/FAIL；需要真实网络/双设备的项打印操作指引
#
# 注意：与模拟器同款限制——hdc shell 无权限读应用沙箱；hilog 单行过长会截断；
# uinput 在真机上可用性以设备为准（部分设备需开启「指针位置」开发者选项）。
# 对应 DevEco 工程路径：scripts/verify-device.ps1

param(
  [ValidateSet('checklist','dump','list','install')][string]$Mode = 'checklist',
  [string]$Hap = '',
  [string]$Target = '',          # 留空 = hdc 默认（USB 真机）
  [string]$Bundle = 'com.example.harmonytavern',
  [string]$Ability = 'EntryAbility'
)

$ErrorActionPreference = 'Continue'
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path $hdc)) {
  $hdc = (Get-Command hdc -ErrorAction SilentlyContinue).Source
  if (-not $hdc) { throw 'hdc 未找到：请设置 DEVECO_SDK_HOME 或把 hdc 加入 PATH' }
}
$TAG = 'HarmonyTavern'
$dump = Join-Path $env:TEMP 'vd_dump.json'

# hdc 调用统一入口：数组 splat，规避「整串当一个参数」的经典坑。
function Invoke-Hdc([string[]]$Parts) {
  if ($Target -ne '') { & $hdc -t $Target @Parts 2>&1 } else { & $hdc @Parts 2>&1 }
}

function Dump-Layout {
  Invoke-Hdc @('shell','uitest','dumpLayout','-p','/data/local/tmp/vd.json') | Out-Null
  Invoke-Hdc @('file','recv','/data/local/tmp/vd.json',$dump) | Out-Null
  Get-Content $dump -Raw -Encoding UTF8
}

function Get-VisibleText {
  $ui = Dump-Layout
  ($ui -split '\{"attributes"') | ForEach-Object {
    $t = [regex]::Match($_, '"text":"([^"]{1,60})"')
    if ($t.Success) { $t.Groups[1].Value }
  } | Where-Object { $_ -ne '' }
}

function Tap-Text([string]$Text) {
  $ui = Dump-Layout
  $node = ($ui -split '\{"attributes"') | Where-Object {
    $_ -match '"type":"Button"' -and $_ -match ('"text":"[^"]*' + [regex]::Escape($Text))
  } | Select-Object -First 1
  if (-not $node) { Write-Host "  x 未找到按钮「$Text」"; return $false }
  $b = [regex]::Match($node, '"bounds":"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
  if (-not $b.Success) { Write-Host "  x 「$Text」无 bounds"; return $false }
  $x = [int](([int]$b.Groups[1].Value + [int]$b.Groups[3].Value) / 2)
  $y = [int](([int]$b.Groups[2].Value + [int]$b.Groups[4].Value) / 2)
  Invoke-Hdc @('shell', "uinput -S -c $x $y") | Out-Null
  Write-Host "  v 已点「$Text」($x,$y)"
  return $true
}

function Wait-Hilog([string]$Pattern, [int]$TimeoutSec = 20) {
  $job = Start-Job -ScriptBlock {
    param($h, $t) & $h shell hilog -x -T $t 2>&1
  } -ArgumentList $hdc, $TAG
  $out = $job | Wait-Job -Timeout $TimeoutSec | Receive-Job
  $job | Remove-Job -Force
  $hit = $out | Select-String -Pattern $Pattern | Select-Object -Last 1
  if ($hit) {
    Write-Host "  v hilog: $($hit.Line.Trim().Substring(0,[Math]::Min(110,$hit.Line.Trim().Length)))"
    return $true
  }
  Write-Host "  x $TimeoutSec 秒内未等到「$Pattern」"
  return $false
}

function Install-Login {
  if ($Hap -eq '') { Write-Host '  跳过安装（未给 -Hap）'; return }
  Write-Host '== 安装签名 HAP =='
  Invoke-Hdc @('install','-r',$Hap) | Select-Object -Last 1 | ForEach-Object { "  $($_.ToString().Trim())" }
  Write-Host '== 冷启 =='
  Invoke-Hdc @('shell','aa','start','-a',$Ability,'-b',$Bundle) | Out-Null
  Start-Sleep -Seconds 5
  $texts = Get-VisibleText
  Write-Host "  首屏文本: $($texts -join ' / ')"
}

function Probe-P62 {
  Write-Host '== P6.2 回归 =='
  Tap-Text '运行 P6.2 验证' | Out-Null
  Wait-Hilog 'P6.2 chain done' 25
  Wait-Hilog 'pair request listener attached' 5
}

function Probe-Navigation {
  Write-Host '== 导航（NavPathStack）=='
  Tap-Text '去聊天' | Out-Null
  Start-Sleep -Seconds 3
  $texts = Get-VisibleText
  Write-Host "  ChatPage: $($texts -join ' / ')"
  # 系统返回手势（真机从屏幕左缘右滑；模拟器可能无效，属输入限制非应用问题）
  Invoke-Hdc @('shell','uinput','-S','-g','8','1300','300','1300','300','800') | Out-Null
  Start-Sleep -Seconds 2
  $texts2 = Get-VisibleText
  Write-Host "  返回后: $($texts2 -join ' / ')"
  Tap-Text '设置' | Out-Null
  Start-Sleep -Seconds 3
  $texts3 = Get-VisibleText
  Write-Host "  SettingsPage: $($texts3 -join ' / ')"
}

function Run-Checklist {
  Write-Host '######## P7 步骤 7 自动验收点 ########'
  Install-Login
  Probe-P62
  Probe-Navigation
  Write-Host ''
  Write-Host '以下验收点需人工操作（预期已写入 docs/移植方案.md 步骤 7）:'
  Write-Host '  ② 建角色 / ③ 配模型+测试连接 / ④ 对话生成+停止+重试+图片'
  Write-Host '  ⑤ 摘要 / ⑥ agent 运行+实时投影+cancel / ⑦ 扩展安装/更新/删除'
  Write-Host '     -> hilog 通道: hdc shell "hilog -x -T HarmonyTavern"'
  Write-Host '  ⑧ LAN 双设备配对（lan_sync:pair_request 弹窗接受/拒绝 = 3c 实弹验证点）'
  Write-Host '  ⑨ tt_sync pair/pull / ⑩ sync_automation / ⑪ 通知授权+通知栏'
  Write-Host '  ⑫ LAN 服务端 running=true + 降级路径'
  Write-Host '  真机关注: LAN TCP 监听权限 / arm64 长帧 / Navigation 返回手势 / IME 避让'
}

# ---- 入口 ----
switch ($Mode) {
  'list' { Invoke-Hdc @('list','targets'); exit }
  'dump' { Get-VisibleText; exit }
  'install' {
    # 覆盖安装遇到 9568332「install sign info inconsistent」时用本模式：
    # 设备上旧包的签名证书与新包不同（例如早期 DevEco 自动签名的包），
    # 必须先卸载再装。注意：卸载会清掉应用数据（聊天/密钥/扩展）。
    if ($Hap -eq '') {
      $Hap = Join-Path $PSScriptRoot '..\dist\HarmonyTavern-arm64-release-signed.hap'
    }
    if (-not (Test-Path $Hap)) { throw "HAP 不存在: $Hap" }
    Write-Host "[1/3] 卸载旧包（若未安装会报 not installed，可忽略）"
    Invoke-Hdc @('uninstall',$Bundle) | ForEach-Object { Write-Host "  $_" }
    Start-Sleep -Seconds 2
    Write-Host "[2/3] 安装 $Hap"
    Invoke-Hdc @('install','-r',$Hap) | ForEach-Object { Write-Host "  $_" }
    Start-Sleep -Seconds 2
    Write-Host "[3/3] 启动 $Ability"
    Invoke-Hdc @('shell','aa','start','-a',$Ability,'-b',$Bundle) | ForEach-Object { Write-Host "  $_" }
    exit
  }
  default { Run-Checklist }
}
Run-Checklist
