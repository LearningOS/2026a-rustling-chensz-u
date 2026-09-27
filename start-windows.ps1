#Requires -Version 5.1
# Set up this checkout for x64 Windows, including a GNU linker.
param([switch]$SetupOnly)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program exited with code $LASTEXITCODE"
    }
}

if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or
    $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    throw 'This setup script requires x64 Windows.'
}

$versionMatch = [regex]::Match(
    (Get-Content -Raw (Join-Path $PSScriptRoot 'rust-toolchain.toml')),
    '(?m)^channel\s*=\s*"(\d+\.\d+\.\d+)"\s*$'
)
if (-not $versionMatch.Success) {
    throw 'Expected an exact Rust version in rust-toolchain.toml.'
}
$toolchain = $versionMatch.Groups[1].Value + '-x86_64-pc-windows-gnu'
$env:RUSTUP_DIST_SERVER = 'https://rsproxy.cn'
$env:RUSTUP_UPDATE_ROOT = 'https://rsproxy.cn/rustup'
$env:RUSTUP_TOOLCHAIN = $toolchain
$setupDir = Join-Path $PSScriptRoot 'tmp/setup'
[void](New-Item -ItemType Directory -Force -Path $setupDir)
$env:TMPDIR = $setupDir
$env:TEMP = $setupDir
$env:TMP = $setupDir

if ($env:CARGO_HOME) {
    $cargoHome = $env:CARGO_HOME
} else {
    $cargoHome = Join-Path $env:USERPROFILE '.cargo'
}
$cargoBin = Join-Path $cargoHome 'bin'
$env:PATH = $cargoBin + ';' + $env:PATH

if (-not (Get-Command rustup.exe -ErrorAction SilentlyContinue)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installer = Join-Path $setupDir 'rustup-init.exe'
    $url = "$env:RUSTUP_UPDATE_ROOT/dist/x86_64-pc-windows-gnu/rustup-init.exe"
    Write-Host 'Downloading Rust installer from RsProxy...'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
    $checksumResponse = Invoke-WebRequest -UseBasicParsing -Uri "$url.sha256"
    $expectedHash = ([string]$checksumResponse.Content).Trim().Split(' ')[0]
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $installer).Hash
    if ($expectedHash -notmatch '^[0-9a-fA-F]{64}$' -or $actualHash -ine $expectedHash) {
        throw 'Rust installer SHA256 verification failed.'
    }
    Invoke-Checked $installer @('-y', '--default-host', 'x86_64-pc-windows-gnu',
        '--default-toolchain', 'none', '--profile', 'minimal', '--no-modify-path')
}

Write-Host "Installing $toolchain from RsProxy..."
Invoke-Checked 'rustup.exe' @('toolchain', 'install', $toolchain, '--profile', 'minimal',
    '--component', 'clippy', '--component', 'rust-mingw', '--no-self-update', '--no-update')
Invoke-Checked 'rustup.exe' @('override', 'set', $toolchain)
Invoke-Checked 'rustc.exe' @('--version')
Invoke-Checked 'cargo.exe' @('--version')
if ($SetupOnly) {
    Invoke-Checked 'cargo.exe' @('build', '--locked')
} else {
    Invoke-Checked 'cargo.exe' @('run', '--locked', '--', 'watch')
}
