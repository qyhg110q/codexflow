param(
    [string]$Version,
    [switch]$SkipApk,
    [switch]$SkipWeb,
    [switch]$SkipAgentBuild,
    [switch]$SkipLinux
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterProject = Join-Path $repoRoot "flutter\codexflow"
$flutterBat = Join-Path $repoRoot ".tooling\flutter\bin\flutter.bat"
$agentExe = Join-Path $repoRoot "codexflow-agent.exe"
$linuxAgent = Join-Path $repoRoot "artifacts\codexflow-agent-linux-amd64"
$apkSource = Join-Path $flutterProject "build\app\outputs\flutter-apk\app-release.apk"
$webSource = Join-Path $flutterProject "build\web"
$releaseRoot = Join-Path $repoRoot "artifacts\release"
$windowsTemplateRoot = Join-Path $repoRoot "scripts\release\windows"
$linuxTemplateRoot = Join-Path $repoRoot "scripts\release\linux"

function Get-AppVersion {
    $pubspecPath = Join-Path $flutterProject "pubspec.yaml"
    $line = Select-String -Path $pubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
    if (-not $line) {
        throw "Could not read version from $pubspecPath"
    }

    return $line.Matches[0].Groups[1].Value.Trim()
}

function Get-ReleaseVersionLabel {
    param([string]$RawVersion)

    $baseVersion = $RawVersion
    if ($RawVersion -match '^([^+]+)') {
        $baseVersion = $Matches[1]
    }

    if ($baseVersion -notmatch '^v') {
        return "v$baseVersion"
    }

    return $baseVersion
}

function Ensure-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Remove-IfExists([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
    }
}

function Build-AgentBinary {
    $goCommand = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCommand) {
        throw "Go was not found in PATH."
    }

    Push-Location $repoRoot
    try {
        & $goCommand.Path build -o $agentExe ./cmd/codexflow-agent
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

function Build-LinuxAgentBinary {
    $goCommand = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCommand) {
        throw "Go was not found in PATH."
    }

    Push-Location $repoRoot
    try {
        $previousGoos = $env:GOOS
        $previousGoarch = $env:GOARCH
        $previousCgo = $env:CGO_ENABLED
        $env:GOOS = "linux"
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "0"
        & $goCommand.Path build -trimpath -o $linuxAgent ./cmd/codexflow-agent
        if ($LASTEXITCODE -ne 0) {
            throw "go build linux/amd64 failed with exit code $LASTEXITCODE"
        }
    } finally {
        $env:GOOS = $previousGoos
        $env:GOARCH = $previousGoarch
        $env:CGO_ENABLED = $previousCgo
        Pop-Location
    }
}

function Build-Web {
    if (-not (Test-Path $flutterBat)) {
        throw "Flutter SDK was not found at $flutterBat"
    }

    $packageConfig = Join-Path $flutterProject ".dart_tool\package_config.json"
    if (-not (Test-Path $packageConfig)) {
        throw "Missing Flutter package config. Run build_android_apk.ps1 first, or run flutter pub get in an environment with symlink support."
    }

    Push-Location $flutterProject
    try {
        & $flutterBat build web --release --no-pub
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build web failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

$rawVersion = if ($Version) { $Version } else { Get-AppVersion }
$releaseVersion = Get-ReleaseVersionLabel -RawVersion $rawVersion
$outputRoot = Join-Path $releaseRoot $releaseVersion
$windowsBundleRoot = Join-Path $outputRoot "codexflow-windows-host"
$linuxBundleRoot = Join-Path $outputRoot "codexflow-linux-host"
$windowsZip = Join-Path $outputRoot ("codexflow-windows-host-{0}.zip" -f $releaseVersion)
$linuxTarGz = Join-Path $outputRoot ("codexflow-linux-host-{0}.tar.gz" -f $releaseVersion)
$webZip = Join-Path $outputRoot ("codexflow-web-{0}.zip" -f $releaseVersion)
$apkTarget = Join-Path $outputRoot ("codexflow-android-{0}.apk" -f $releaseVersion)
$shaFile = Join-Path $outputRoot "SHA256SUMS.txt"
$notesFile = Join-Path $outputRoot "release-notes.md"

Ensure-Directory $outputRoot
Remove-IfExists $windowsBundleRoot
Remove-IfExists $linuxBundleRoot

if (-not $SkipAgentBuild) {
    Build-AgentBinary
    if (-not $SkipLinux) {
        Build-LinuxAgentBinary
    }
}

if (-not $SkipApk) {
    & (Join-Path $repoRoot "build_android_apk.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "build_android_apk.ps1 failed with exit code $LASTEXITCODE"
    }
}

if (-not $SkipWeb) {
    Build-Web
}

if (-not (Test-Path $agentExe)) {
    throw "Missing agent binary: $agentExe"
}

if ((-not $SkipLinux) -and (-not (Test-Path $linuxAgent))) {
    throw "Missing Linux agent binary: $linuxAgent"
}

if (-not (Test-Path $webSource)) {
    throw "Missing web build output: $webSource"
}

if ((-not $SkipApk) -and (-not (Test-Path $apkSource))) {
    throw "Missing APK output: $apkSource"
}

Ensure-Directory $windowsBundleRoot
Copy-Item $agentExe -Destination (Join-Path $windowsBundleRoot "codexflow-agent.exe") -Force
Copy-Item (Join-Path $windowsTemplateRoot "README.md") -Destination (Join-Path $windowsBundleRoot "README.md") -Force
Copy-Item (Join-Path $windowsTemplateRoot "codexflow-agent.json") -Destination (Join-Path $windowsBundleRoot "codexflow-agent.json") -Force
Copy-Item $webSource -Destination (Join-Path $windowsBundleRoot "web") -Recurse -Force

if (Test-Path $windowsZip) {
    Remove-Item $windowsZip -Force
}
Compress-Archive -Path (Join-Path $windowsBundleRoot "*") -DestinationPath $windowsZip

if (-not $SkipLinux) {
    Ensure-Directory $linuxBundleRoot
    Copy-Item $linuxAgent -Destination (Join-Path $linuxBundleRoot "codexflow-agent") -Force
    Copy-Item (Join-Path $linuxTemplateRoot "README.md") -Destination (Join-Path $linuxBundleRoot "README.md") -Force
    Copy-Item (Join-Path $linuxTemplateRoot "codexflow-agent.json") -Destination (Join-Path $linuxBundleRoot "codexflow-agent.json") -Force
    Copy-Item $webSource -Destination (Join-Path $linuxBundleRoot "web") -Recurse -Force

    if (Test-Path $linuxTarGz) {
        Remove-Item $linuxTarGz -Force
    }
    Push-Location $outputRoot
    try {
        tar -czf (Split-Path $linuxTarGz -Leaf) "codexflow-linux-host"
        if ($LASTEXITCODE -ne 0) {
            throw "tar failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

if (Test-Path $webZip) {
    Remove-Item $webZip -Force
}
Compress-Archive -Path (Join-Path $webSource "*") -DestinationPath $webZip

if (-not $SkipApk) {
    Copy-Item $apkSource -Destination $apkTarget -Force
}

$assets = @($windowsZip, $webZip)
if (-not $SkipLinux) {
    $assets += $linuxTarGz
}
if (-not $SkipApk) {
    $assets += $apkTarget
}

$shaLines = foreach ($asset in $assets) {
    $hash = Get-FileHash -Path $asset -Algorithm SHA256
    "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path $asset -Leaf)
}
Set-Content -Path $shaFile -Value $shaLines -Encoding ASCII

$notes = @"
# CodexFlow $releaseVersion

Recommended assets:

- `codexflow-windows-host-$releaseVersion.zip`: Windows host bundle with agent and bundled web UI.
- `codexflow-linux-host-$releaseVersion.tar.gz`: Linux amd64 host bundle for Ubuntu with agent and bundled web UI.
- `codexflow-android-$releaseVersion.apk`: Android client APK.
- `codexflow-web-$releaseVersion.zip`: standalone static web build for custom hosting.
- `SHA256SUMS.txt`: checksums for release assets.

Deployment notes:

- Most users should start with the Windows host bundle.
- Ubuntu users can unpack the Linux host bundle, run `chmod +x codexflow-agent`, then start `./codexflow-agent`.
- Android APK belongs in the same release because it is part of the same end-user product surface and GitHub Releases handles multi-asset distribution well.
- iOS signed distribution is not included in this release flow.
"@
Set-Content -Path $notesFile -Value $notes -Encoding UTF8

Write-Host ""
Write-Host ("Release assets prepared in {0}" -f $outputRoot)
Write-Host ("Windows bundle: {0}" -f $windowsZip)
if (-not $SkipLinux) {
    Write-Host ("Linux bundle:   {0}" -f $linuxTarGz)
}
Write-Host ("Web zip:        {0}" -f $webZip)
if (-not $SkipApk) {
    Write-Host ("Android APK:    {0}" -f $apkTarget)
}
Write-Host ("Checksums:      {0}" -f $shaFile)
Write-Host ("Release notes:  {0}" -f $notesFile)
