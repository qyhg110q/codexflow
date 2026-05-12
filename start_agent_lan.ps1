$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $repoRoot "codexflow-agent.exe"
$dataDir = Join-Path $repoRoot "data"
$logDir = Join-Path $repoRoot "logs"
$pidFile = Join-Path $repoRoot "codexflow-agent.pid"
$stateDbPath = Join-Path $dataDir "codexflow-state.db"
$stdoutLog = Join-Path $logDir "agent.stdout.log"
$stderrLog = Join-Path $logDir "agent.stderr.log"
$codexPath = "C:\Users\yehuaige\AppData\Roaming\npm\codex.cmd"

function Get-NewestSourceWriteTime {
    $sourceRoots = @(
        (Join-Path $repoRoot "cmd"),
        (Join-Path $repoRoot "internal"),
        (Join-Path $repoRoot "go.mod"),
        (Join-Path $repoRoot "go.sum")
    )

    $items = foreach ($sourceRoot in $sourceRoots) {
        if (Test-Path $sourceRoot -PathType Container) {
            Get-ChildItem -Path $sourceRoot -Recurse -File -Include *.go -ErrorAction SilentlyContinue
        } elseif (Test-Path $sourceRoot -PathType Leaf) {
            Get-Item $sourceRoot
        }
    }

    return ($items | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
}

function Test-AgentBinaryIsStale {
    if (-not (Test-Path $exePath)) {
        return $true
    }

    $newestSourceWriteTime = Get-NewestSourceWriteTime
    if (-not $newestSourceWriteTime) {
        return $false
    }

    $exeWriteTime = (Get-Item $exePath).LastWriteTimeUtc
    return $exeWriteTime -lt $newestSourceWriteTime
}

function Build-AgentBinary {
    $goCommand = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCommand) {
        throw "Go is required to build codexflow-agent.exe, but 'go' was not found in PATH"
    }

    Write-Host "Building codexflow-agent.exe from current source..."
    Push-Location $repoRoot
    try {
        & $goCommand.Path build -o $exePath ./cmd/codexflow-agent
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

function Get-LanIpAddress {
    $connectedInterfaces = Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ConnectionState -eq "Connected" }
    $connectionProfiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue

    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "198.18.0.1" -and
            $_.AddressState -eq "Preferred" -and
            ($connectedInterfaces.InterfaceIndex -contains $_.InterfaceIndex)
        } |
        ForEach-Object {
            $ip = $_
            $iface = $connectedInterfaces | Where-Object { $_.InterfaceIndex -eq $ip.InterfaceIndex } | Select-Object -First 1
            $profile = $connectionProfiles | Where-Object { $_.InterfaceIndex -eq $ip.InterfaceIndex } | Select-Object -First 1
            $connectivityRank = if ($profile -and $profile.IPv4Connectivity -eq "Internet") { 0 } else { 1 }
            [PSCustomObject]@{
                IPAddress = $ip.IPAddress
                InterfaceAlias = $ip.InterfaceAlias
                InterfaceMetric = $iface.InterfaceMetric
                ConnectivityRank = $connectivityRank
            }
        }

    $preferred = $candidates |
        Where-Object { $_.InterfaceAlias -match "WLAN|Wi-Fi|Ethernet|以太网" } |
        Sort-Object ConnectivityRank, InterfaceMetric |
        Select-Object -First 1
    if ($preferred) {
        return $preferred.IPAddress
    }

    $fallback = $candidates | Sort-Object ConnectivityRank, InterfaceMetric | Select-Object -First 1
    if ($fallback) {
        return $fallback.IPAddress
    }

    return "127.0.0.1"
}

if (-not (Test-Path $exePath)) {
    Write-Host "Missing agent binary: $exePath"
}

if (-not (Test-Path $codexPath)) {
    throw "Missing codex command: $codexPath"
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (Test-Path $pidFile) {
    $existingPid = (Get-Content $pidFile -Raw).Trim()
    if ($existingPid) {
        $existingProcess = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($existingProcess) {
            if (Test-AgentBinaryIsStale) {
                Write-Host "Existing codexflow-agent is using an older binary. Restarting with current source..."
                Stop-Process -Id $existingPid -Force
                Start-Sleep -Seconds 1
            } else {
                $lanIp = Get-LanIpAddress
                Write-Host "codexflow-agent is already running. PID=$existingPid"
                Write-Host "LAN URL: http://$lanIp`:4318"
                Write-Host "Health check: http://$lanIp`:4318/healthz"
                exit 0
            }
        }
    }
    Remove-Item $pidFile -Force
}

if (Test-AgentBinaryIsStale) {
    Build-AgentBinary
}

$env:CODEXFLOW_LISTEN_ADDR = "0.0.0.0:4318"
$env:CODEXFLOW_CODEX_PATH = $codexPath
$env:CODEXFLOW_STATE_DB_PATH = $stateDbPath

$process = Start-Process `
    -FilePath $exePath `
    -WorkingDirectory $repoRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutLog `
    -RedirectStandardError $stderrLog `
    -PassThru

Start-Sleep -Seconds 3

if ($process.HasExited) {
    throw "codexflow-agent exited early. Check logs in $logDir"
}

Set-Content -Path $pidFile -Value $process.Id
$lanIp = Get-LanIpAddress
Write-Host "codexflow-agent started. PID=$($process.Id)"
Write-Host "LAN URL: http://$lanIp`:4318"
Write-Host "Health check: http://$lanIp`:4318/healthz"
