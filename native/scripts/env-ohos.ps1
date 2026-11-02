# Cross-compile environment for OpenHarmony (PowerShell port of upstream scripts/ohos/env.sh).
# Usage (dot-source from build.ps1):
#   . .\scripts\env-ohos.ps1 -Arch x86_64      # emulator
#   . .\scripts\env-ohos.ps1 -Arch arm64-v8a   # device
# NOTE: keep this file pure ASCII. Non-ASCII bytes get misdecoded under the
# host's GBK codepage and can swallow the newline, merging the next line into
# a comment (this already broke the build twice).
param(
  [ValidateSet('x86_64', 'arm64-v8a')]
  [string]$Arch = 'x86_64'
)
$ErrorActionPreference = 'Stop'

# OHOS NDK bundled with DevEco Studio (detected on this machine; adjust when moving hosts).
# Space-free junctions C:\ohos-ndk / C:\ohos-sdk are used because rustc/cc split env values
# on whitespace. napi-build-ohos requires OHOS_NDK_HOME to be the SDK root containing native/.
$OHOS_NDK_HOME = 'C:\ohos26-sdk'
$OHOS_NATIVE_HOME = 'C:\ohos26-ndk'
$devEcoSdk = 'C:\Program Files\Huawei\DevEco Studios\DevEco Studio\sdk\default\openharmony'
if (-not (Test-Path $OHOS_NATIVE_HOME) -and (Test-Path (Join-Path $devEcoSdk 'native'))) {
  New-Item -ItemType Junction -Path $OHOS_NATIVE_HOME -Target (Join-Path $devEcoSdk 'native') | Out-Null
}
if (-not (Test-Path $OHOS_NDK_HOME) -and (Test-Path $devEcoSdk)) {
  New-Item -ItemType Junction -Path $OHOS_NDK_HOME -Target $devEcoSdk | Out-Null
}
if (-not (Test-Path (Join-Path $OHOS_NATIVE_HOME 'llvm\bin\clang.exe'))) {
  $OHOS_NATIVE_HOME = Join-Path $devEcoSdk 'native'
  $OHOS_NDK_HOME = $devEcoSdk
}
if (-not (Test-Path (Join-Path $OHOS_NATIVE_HOME 'llvm\bin\clang.exe'))) {
  throw "OHOS NDK not found (checked C:\ohos-ndk and the DevEco default SDK path)"
}

switch ($Arch) {
  'x86_64'    { $ohosArch = 'x86_64';  $triple = 'x86_64-unknown-linux-ohos';   $abi = 'x86_64' }
  'arm64-v8a' { $ohosArch = 'aarch64'; $triple = 'aarch64-unknown-linux-ohos'; $abi = 'arm64-v8a' }
}

$env:OHOS_NDK_HOME    = $OHOS_NDK_HOME
$env:OHOS_NATIVE_HOME = $OHOS_NATIVE_HOME
$env:OHOS_ARCH        = $Arch
$env:TARGET_TRIPLE    = $triple
$env:TT_ABI           = $abi

$llvmBin = Join-Path $OHOS_NATIVE_HOME 'llvm\bin'
$sysroot = Join-Path $OHOS_NATIVE_HOME 'sysroot'
# Junction paths have no spaces, so no quoting: rustc/cc split env values on
# whitespace and literal quotes would be passed through to the tools verbatim.
$ccArgs   = "--target=$ohosArch-linux-ohos --sysroot=$sysroot -D__MUSL__"
$linkArgs = "-C link-arg=--target=$ohosArch-linux-ohos -C link-arg=--sysroot=$sysroot -C link-arg=-fuse-ld=lld"

# aws-lc-sys and friends need cmake/ninja (bundled with the DevEco NDK).
$env:PATH = "$llvmBin;" + (Join-Path $OHOS_NATIVE_HOME 'build-tools\cmake\bin') + ";$env:PATH"
# aws-lc-sys' find_cmake_command prefers the CMAKE env var over PATH lookup.
$env:CMAKE = Join-Path $OHOS_NATIVE_HOME 'build-tools\cmake\bin\cmake.exe'
# The cmake crate defaults to the NMake generator on Windows hosts, but this
# machine has no nmake (MSVC); Ninja ships with the DevEco NDK cmake bundle.
$env:CMAKE_GENERATOR = 'Ninja'

$u = $triple.Replace('-', '_')     # e.g. x86_64_unknown_linux_ohos
$U = $u.ToUpper()

# The cc crate looks up CC_<target> under several spellings; set both hyphenated
# and underscored variants (Windows env vars are case-insensitive anyway).
foreach ($sep in @($triple, $u)) {
  Set-Item "Env:CC_$sep"        (Join-Path $llvmBin 'clang.exe')
  Set-Item "Env:CXX_$sep"       (Join-Path $llvmBin 'clang++.exe')
  Set-Item "Env:CFLAGS_$sep"    $ccArgs
  Set-Item "Env:CXXFLAGS_$sep"  $ccArgs
  Set-Item "Env:AR_$sep"        (Join-Path $llvmBin 'llvm-ar.exe')
  Set-Item "Env:RANLIB_$sep"    (Join-Path $llvmBin 'llvm-ranlib.exe')
  Set-Item "Env:CXXSTDLIB_$sep" 'c++'
}

# rustc linking: use clang as the linker driver with target/sysroot args
Set-Item "Env:CARGO_TARGET_${U}_LINKER"    (Join-Path $llvmBin 'clang.exe')
Set-Item "Env:CARGO_TARGET_${U}_RUSTFLAGS" $linkArgs

# bindgen (used later by napi/FFI build scripts). Set both the target-suffixed
# and the plain fallback spelling (bindgen checks suffix -> underscore -> plain).
# IMPORTANT: bindgen splits the value with POSIX shlex, which eats backslashes,
# so the sysroot MUST use forward slashes here (backslashes are fine elsewhere:
# rustc/cc pass argv tokens verbatim).
$bindgenArgs = "--target=$ohosArch-linux-ohos --sysroot=$($sysroot.Replace('\','/'))"
Set-Item "Env:BINDGEN_EXTRA_CLANG_ARGS_$u" $bindgenArgs
$env:BINDGEN_EXTRA_CLANG_ARGS = $bindgenArgs

Write-Host "OHOS cross-compile env ready: triple=$triple abi=$abi"
Write-Host "  NDK: $OHOS_NATIVE_HOME"
