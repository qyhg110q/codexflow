$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterProject = Join-Path $repoRoot "flutter\codexflow"
$toolingRoot = Join-Path $repoRoot ".tooling"
$downloadRoot = Join-Path $toolingRoot "downloads"
$sdkRoot = Join-Path $toolingRoot "sdk"
$flutterRoot = Join-Path $toolingRoot "flutter"
$androidSdkRoot = Join-Path $sdkRoot "android"
$jdkParent = Join-Path $sdkRoot "jdk"
$pubCache = Join-Path $toolingRoot "pub-cache"
$gradleHome = Join-Path $toolingRoot "gradle"
$androidPackages = @(
    "platform-tools",
    "platforms;android-36",
    "build-tools;36.1.0"
)

function Get-LocalProxyUrl {
    $proxyCandidates = @(7890, 7897, 7898)
    foreach ($port in $proxyCandidates) {
        try {
            $listener = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop | Select-Object -First 1
            if ($listener) {
                return "http://127.0.0.1:$port"
            }
        } catch {
        }
    }
    return $null
}

function Ensure-Directory([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Download-File([string]$Url, [string]$Destination) {
    if (Test-Path $Destination) {
        Write-Host "Using existing download: $Destination"
        return
    }
    $attempts = 3
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        try {
            Write-Host "Downloading $Url (attempt $attempt/$attempts)"
            if (Test-Path $Destination) {
                Remove-Item $Destination -Force
            }
            & curl.exe -L --fail --output $Destination $Url
            if (Test-Path $Destination) {
                return
            }
        } catch {
            if (Test-Path $Destination) {
                Remove-Item $Destination -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -eq $attempts) {
                throw
            }
            Start-Sleep -Seconds (5 * $attempt)
        }
    }
}

function Expand-ZipToDirectory([string]$ZipPath, [string]$Destination) {
    if (Test-Path $Destination) {
        return
    }
    Ensure-Directory (Split-Path -Parent $Destination)
    Expand-Archive -Path $ZipPath -DestinationPath (Split-Path -Parent $Destination)
}

function Ensure-FlutterSdk {
    $flutterBat = Join-Path $flutterRoot "bin\flutter.bat"
    if (Test-Path $flutterBat) {
        return $flutterBat
    }

    $zipPath = Join-Path $downloadRoot "flutter_windows_3.41.9-stable.zip"
    $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.9-stable.zip"
    Download-File $url $zipPath
    if (Test-Path $flutterRoot) {
        Remove-Item -Recurse -Force $flutterRoot
    }
    Expand-Archive -Path $zipPath -DestinationPath $toolingRoot
    return $flutterBat
}

function Ensure-Jdk17 {
    $existing = Get-ChildItem $jdkParent -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        return $existing.FullName
    }

    Ensure-Directory $jdkParent
    $zipPath = Join-Path $downloadRoot "OpenJDK17U-jdk_x64_windows_hotspot_17.0.18_8.zip"
    $url = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.18%2B8/OpenJDK17U-jdk_x64_windows_hotspot_17.0.18_8.zip"
    Download-File $url $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $jdkParent
    $installed = Get-ChildItem $jdkParent -Directory | Select-Object -First 1
    if (-not $installed) {
        throw "JDK extraction failed"
    }
    return $installed.FullName
}

function Ensure-AndroidCommandLineTools {
    $sdkManager = Join-Path $androidSdkRoot "cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkManager) {
        return $sdkManager
    }

    Ensure-Directory $androidSdkRoot
    $zipName = "commandlinetools-win-14742923_latest.zip"
    $zipPath = Join-Path $downloadRoot $zipName
    $url = "https://dl.google.com/android/repository/$zipName"
    Download-File $url $zipPath

    $extractRoot = Join-Path $androidSdkRoot "cmdline-tools"
    $tempExtract = Join-Path $extractRoot "tmp"
    if (Test-Path $tempExtract) {
        Remove-Item -Recurse -Force $tempExtract
    }
    Ensure-Directory $extractRoot
    Expand-Archive -Path $zipPath -DestinationPath $tempExtract

    $sourceDir = Join-Path $tempExtract "cmdline-tools"
    $targetDir = Join-Path $extractRoot "latest"
    if (Test-Path $targetDir) {
        Remove-Item -Recurse -Force $targetDir
    }
    Move-Item -LiteralPath $sourceDir -Destination $targetDir
    Remove-Item -Recurse -Force $tempExtract

    return $sdkManager
}

function Ensure-AndroidPackages([string]$SdkManagerPath, [string]$JavaHome) {
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_SDK_ROOT = $androidSdkRoot
    $env:ANDROID_HOME = $androidSdkRoot

    $licenses = Join-Path $androidSdkRoot "licenses\android-sdk-license"
    if (-not (Test-Path $licenses)) {
        Write-Host "Accepting Android SDK licenses"
        $accept = ('y' + [Environment]::NewLine) * 20
        $accept | & $SdkManagerPath --sdk_root=$androidSdkRoot --licenses | Out-Null
    }

    Write-Host "Installing Android SDK packages"
    & $SdkManagerPath --sdk_root=$androidSdkRoot $androidPackages
}

function Write-LocalProperties([string]$FlutterSdkPath) {
    $content = @"
sdk.dir=$($androidSdkRoot -replace '\\','\\')
flutter.sdk=$($FlutterSdkPath -replace '\\','\\')
"@
    Set-Content -Path (Join-Path $flutterProject "android\local.properties") -Value $content -Encoding ASCII
}

Ensure-Directory $toolingRoot
Ensure-Directory $downloadRoot
Ensure-Directory $sdkRoot
Ensure-Directory $pubCache
Ensure-Directory $gradleHome

$flutterBat = Ensure-FlutterSdk
$javaHome = Ensure-Jdk17
$sdkManager = Ensure-AndroidCommandLineTools

$env:JAVA_HOME = $javaHome
$env:ANDROID_SDK_ROOT = $androidSdkRoot
$env:ANDROID_HOME = $androidSdkRoot
$env:PUB_CACHE = $pubCache
$env:GRADLE_USER_HOME = $gradleHome
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:GRADLE_OPTS = "-Dhttps.protocols=TLSv1.2,TLSv1.3 -Dfile.encoding=UTF-8"
$env:PATH = "$javaHome\bin;$androidSdkRoot\platform-tools;$androidSdkRoot\cmdline-tools\latest\bin;$flutterRoot\bin;$env:PATH"

$proxyUrl = Get-LocalProxyUrl
if ($proxyUrl) {
    Write-Host "Using local proxy: $proxyUrl"
    $env:HTTP_PROXY = $proxyUrl
    $env:HTTPS_PROXY = $proxyUrl
    $env:ALL_PROXY = $proxyUrl
    $env:NO_PROXY = "127.0.0.1,localhost"
    $proxyUri = [Uri]$proxyUrl
    $env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dhttp.proxyHost=$($proxyUri.Host) -Dhttp.proxyPort=$($proxyUri.Port) -Dhttps.proxyHost=$($proxyUri.Host) -Dhttps.proxyPort=$($proxyUri.Port) -Djava.net.useSystemProxies=true"
}

Ensure-AndroidPackages -SdkManagerPath $sdkManager -JavaHome $javaHome
Write-LocalProperties -FlutterSdkPath $flutterRoot

Push-Location $flutterProject
try {
    & $flutterBat config --no-analytics | Out-Null
    & $flutterBat doctor -v
    & $flutterBat pub get
    & $flutterBat build apk --release
} finally {
    Pop-Location
}

$apkPath = Join-Path $flutterProject "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    throw "APK not found: $apkPath"
}

Write-Host ""
Write-Host "APK built successfully:"
Write-Host $apkPath
