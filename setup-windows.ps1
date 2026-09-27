#Requires -Version 5.1
# Configure this checkout once, then start Rustlings using the temporary environment.
& {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    function Invoke-Checked {
        param([string]$Program, [string[]]$Arguments)
        & $Program @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Program exited with code $LASTEXITCODE"
        }
    }

    function Find-VisualStudio {
        param([string]$Product = '*', [string[]]$Components = @())
        $vswhere = Get-Command vswhere.exe -ErrorAction SilentlyContinue
        if (-not $vswhere) {
            $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
            if (-not (Test-Path -LiteralPath $vswhere)) { return '' }
        }
        $arguments = @('-latest', '-products', $Product, '-property', 'installationPath')
        if ($Product -ne '*') { $arguments += @('-version', '[17.0,18.0)') }
        if ($Components.Count) { $arguments += @('-requires') + $Components }
        $installation = & $vswhere @arguments
        if ($LASTEXITCODE -ne 0) { throw "vswhere exited with code $LASTEXITCODE" }
        return ($installation -join "`n").Trim()
    }

    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or
        $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        throw 'This setup script requires x64 Windows (Intel / AMD).'
    }
    $versionMatch = [regex]::Match(
        (Get-Content -Raw (Join-Path $PSScriptRoot 'rust-toolchain.toml')),
        '(?m)^channel\s*=\s*"(\d+\.\d+\.\d+)"\s*$'
    )
    if (-not $versionMatch.Success) {
        throw 'Expected an exact Rust version in rust-toolchain.toml.'
    }
    $toolchain = $versionMatch.Groups[1].Value + '-x86_64-pc-windows-msvc'
    $savedEnvironment = @{}
    foreach ($name in @('RUSTUP_DIST_SERVER', 'RUSTUP_UPDATE_ROOT', 'RUSTUP_TOOLCHAIN',
            'PATH', 'TMPDIR', 'TEMP', 'TMP')) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }
    $savedProtocol = [Net.ServicePointManager]::SecurityProtocol
    Push-Location $PSScriptRoot
    try {
        $env:RUSTUP_DIST_SERVER = 'https://rsproxy.cn'
        $env:RUSTUP_UPDATE_ROOT = 'https://rsproxy.cn/rustup'
        $env:RUSTUP_TOOLCHAIN = $toolchain
        $setupDir = Join-Path $PSScriptRoot 'tmp/setup'
        [void](New-Item -ItemType Directory -Force -Path $setupDir)
        $env:TMPDIR = $setupDir
        $env:TEMP = $setupDir
        $env:TMP = $setupDir
        $cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
        $env:PATH = (Join-Path $cargoHome 'bin') + ';' + $env:PATH

        $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            'Microsoft.VisualStudio.Component.Windows11SDK.22621')
        if (-not (Find-VisualStudio -Components $components)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $buildTools = Join-Path $setupDir 'vs_buildtools.exe'
            Write-Host 'Downloading Microsoft Build Tools. Windows may ask for administrator permission.'
            Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile $buildTools
            $signature = Get-AuthenticodeSignature -LiteralPath $buildTools
            if ($signature.Status -ne 'Valid' -or
                $signature.SignerCertificate.Subject -notmatch '(^|,\s*)O=Microsoft Corporation(,|$)') {
                throw 'Microsoft Build Tools installer signature verification failed.'
            }
            $arguments = @('--passive', '--wait', '--norestart',
                '--add', $components[0], '--add', $components[1], '--addProductLang', 'en-US')
            $existing = Find-VisualStudio -Product 'Microsoft.VisualStudio.Product.BuildTools'
            if ($existing) {
                $arguments = @('modify', '--installPath', ('"' + $existing + '"')) + $arguments
            }
            $process = Start-Process -FilePath $buildTools -ArgumentList $arguments -Verb RunAs -Wait -PassThru
            if ($process.ExitCode -eq 3010 -or $process.ExitCode -eq 1641) {
                throw 'Build Tools requires a Windows restart. Restart and run this script again.'
            }
            if ($process.ExitCode -ne 0) {
                throw "Microsoft Build Tools installer exited with code $($process.ExitCode)"
            }
            if (-not (Find-VisualStudio -Components $components)) {
                throw 'MSVC or Windows SDK is still missing after installation. Check the installer result.'
            }
        }

        if (-not (Get-Command rustup.exe -ErrorAction SilentlyContinue)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $installer = Join-Path $setupDir 'rustup-init.exe'
            $url = "$env:RUSTUP_UPDATE_ROOT/dist/x86_64-pc-windows-msvc/rustup-init.exe"
            Write-Host 'Downloading Rust installer from RsProxy...'
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installer
            $checksumFile = $installer + '.sha256'
            Invoke-WebRequest -UseBasicParsing -Uri "$url.sha256" -OutFile $checksumFile
            $expectedHash = (Get-Content -Raw $checksumFile).Trim().Split(' ')[0]
            if ($expectedHash -notmatch '^[0-9a-fA-F]{64}$' -or
                (Get-FileHash -Algorithm SHA256 -Path $installer).Hash -ine $expectedHash) {
                throw 'Rust installer SHA256 verification failed.'
            }
            Invoke-Checked $installer @('-y', '--default-host', 'x86_64-pc-windows-msvc',
                '--default-toolchain', 'none', '--profile', 'minimal')
        }
        Invoke-Checked 'rustup.exe' @('toolchain', 'install', $toolchain, '--profile', 'minimal',
            '--component', 'clippy', '--no-self-update', '--no-update')
        Invoke-Checked 'rustup.exe' @('override', 'set', $toolchain, '--path', $PSScriptRoot)

        # This file stays local; existing personal Cargo settings are preserved.
        [void](New-Item -ItemType Directory -Force -Path '.cargo')
        if (-not (Test-Path '.cargo/config.toml')) {
            $config = @'
[build]
target-dir = "tmp/target"

[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
'@
            [IO.File]::WriteAllText((Join-Path $PSScriptRoot '.cargo/config.toml'), $config + "`n")
        }
        Write-Host 'Environment ready. Starting exercises; enter quit to exit.'
        Invoke-Checked 'cargo.exe' @('run', '--', 'watch')
    } finally {
        foreach ($name in $savedEnvironment.Keys) {
            if ($null -eq $savedEnvironment[$name]) {
                if (Test-Path "Env:$name") { Remove-Item "Env:$name" }
            } else {
                Set-Item "Env:$name" $savedEnvironment[$name]
            }
        }
        [Net.ServicePointManager]::SecurityProtocol = $savedProtocol
        Pop-Location
    }
}
