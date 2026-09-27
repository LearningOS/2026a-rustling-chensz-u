# Check setup's PowerShell control flow without installing a Windows toolchain.
# The real Rustup and Cargo processes are replaced only inside this test process.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$setup = Join-Path $root 'setup-windows.ps1'
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($setup, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors -join "`n") }
Write-Output 'PowerShell syntax: PASS'

$env:OS = 'Windows_NT'
$env:PROCESSOR_ARCHITECTURE = 'AMD64'
$env:USERPROFILE = Join-Path $root 'tmp/setup-test-user'
$env:CARGO_HOME = Join-Path $root 'tmp/setup-test-cargo'
$env:RUSTUP_DIST_SERVER = 'https://original.invalid'
$env:RUSTUP_UPDATE_ROOT = 'https://original.invalid/rustup'
$names = @('RUSTUP_DIST_SERVER', 'RUSTUP_UPDATE_ROOT', 'RUSTUP_TOOLCHAIN', 'PATH', 'TMPDIR', 'TEMP', 'TMP')
$before = @{}
foreach ($name in $names) { $before[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$protocol = [Net.ServicePointManager]::SecurityProtocol
$config = Join-Path $root '.cargo/config.toml'
$original = if (Test-Path $config) { [IO.File]::ReadAllBytes($config) } else { $null }
$script:Calls = [Collections.Generic.List[string]]::new()
function rustup.exe {
    $script:Calls.Add('rustup ' + ($args -join ' '))
    $global:LASTEXITCODE = if ($script:FailStage -eq 'install') { 42 } else { 0 }
}
function cargo.exe {
    $script:Calls.Add('cargo ' + ($args -join ' '))
    if ($env:RUSTUP_DIST_SERVER -ne 'https://rsproxy.cn') { throw 'Mirror absent during Cargo invocation' }
    if ($env:RUSTUP_TOOLCHAIN -ne '1.98.1-x86_64-pc-windows-msvc') { throw 'MSVC toolchain absent during Cargo invocation' }
    $global:LASTEXITCODE = if ($script:FailStage -eq 'cargo') { 43 } else { 0 }
}
function vswhere.exe {
    $global:LASTEXITCODE = 0
    if ($args -contains '-requires') {
        if ($script:MsvcInstalled) { return 'C:\Program Files\Microsoft Visual Studio\2022\BuildTools' }
    } elseif ($script:FailStage -eq 'msvc_modify') {
        return 'C:\Program Files\Microsoft Visual Studio\2022\BuildTools'
    }
}
function Invoke-WebRequest {
    param($Uri, $OutFile, [switch]$UseBasicParsing)
    if ($Uri -ne 'https://aka.ms/vs/17/release/vs_buildtools.exe') { throw "Unexpected download: $Uri" }
    $script:Calls.Add('download Build Tools')
}
function Get-AuthenticodeSignature {
    param($LiteralPath)
    return [pscustomobject]@{
        Status = if ($script:FailStage -eq 'msvc_signature') { 'NotSigned' } else { 'Valid' }
        SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation, C=US' }
    }
}
function Start-Process {
    param($FilePath, $ArgumentList, $Verb, [switch]$Wait, [switch]$PassThru)
    if ($Verb -ne 'RunAs' -or -not $Wait -or -not $PassThru) { throw 'Installer elevation or waiting missing' }
    foreach ($argument in @('--norestart', '--passive', '--wait',
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', 'Microsoft.VisualStudio.Component.Windows11SDK.22621')) {
        if ($ArgumentList -notcontains $argument) { throw "Installer argument missing: $argument" }
    }
    if ($script:FailStage -eq 'msvc_modify') {
        if ($ArgumentList[0] -ne 'modify' -or
            $ArgumentList[2] -ne '"C:\Program Files\Microsoft Visual Studio\2022\BuildTools"') {
            throw 'Existing Build Tools path was not quoted for modification'
        }
    }
    $script:Calls.Add('install Build Tools')
    $script:MsvcInstalled = $script:FailStage -ne 'msvc_missing'
    $code = switch ($script:FailStage) {
        'msvc_failure' { 1603 }
        'msvc_reboot' { 3010 }
        default { 0 }
    }
    return [pscustomobject]@{ ExitCode = $code }
}
try {
    foreach ($stage in @('success', 'msvc_install', 'msvc_modify', 'msvc_failure',
            'msvc_reboot', 'msvc_missing', 'msvc_signature', 'install', 'cargo')) {
        $script:FailStage = $stage
        $script:MsvcInstalled = -not $stage.StartsWith('msvc_')
        $script:Calls.Clear()
        if ($stage -eq 'success' -and (Test-Path $config)) { [IO.File]::Delete($config) }
        $caught = $null
        try { . $setup } catch { $caught = $_ }
        $shouldPass = $stage -in @('success', 'msvc_install', 'msvc_modify')
        if ($shouldPass -and $caught) { throw $caught }
        if (-not $shouldPass -and -not $caught) { throw 'Native command failure was ignored' }
        if ($caught) { Write-Output ('Expected failure: ' + $caught.Exception.Message) }
        $expectedError = switch ($stage) {
            'msvc_failure' { 'exited with code 1603' }
            'msvc_reboot' { 'requires a Windows restart' }
            'msvc_missing' { 'still missing after installation' }
            'msvc_signature' { 'signature verification failed' }
            'install' { 'exited with code 42' }
            'cargo' { 'exited with code 43' }
        }
        if ($caught -and $caught.Exception.Message -notlike "*$expectedError*") { throw $caught }
        if ($stage -in @('success', 'install', 'cargo', 'msvc_signature') -and
            $script:Calls.Contains('install Build Tools')) { throw 'Build Tools installed unnecessarily or without signature validation' }
        if ($stage.StartsWith('msvc_') -and -not $shouldPass -and $script:Calls.Contains('cargo run -- watch')) {
            throw 'Cargo started after an unsuccessful Build Tools installation'
        }
        foreach ($name in $names) {
            if ([Environment]::GetEnvironmentVariable($name, 'Process') -cne $before[$name]) {
                throw "Environment leaked: $name"
            }
        }
        if ((Get-Location).Path -cne $root) { throw 'Working directory leaked' }
        if ([Net.ServicePointManager]::SecurityProtocol -ne $protocol) { throw 'TLS setting leaked' }
        if ($shouldPass) {
            if (-not $script:Calls.Contains('cargo run -- watch')) { throw 'Watch was not started' }
            if (-not $script:Calls.Contains('rustup override set 1.98.1-x86_64-pc-windows-msvc --path ' + $root)) {
                throw 'Repository override missing'
            }
            if ([IO.File]::ReadAllText($config) -notmatch 'sparse\+https://rsproxy.cn/index/') { throw 'Local mirror config missing' }
        }
        Write-Output "Environment restoration ($stage): PASS"
    }
} finally {
    if ($null -eq $original) {
        if (Test-Path $config) { [IO.File]::Delete($config) }
    } else {
        [IO.File]::WriteAllBytes($config, $original)
    }
}
