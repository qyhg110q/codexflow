$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $repoRoot "codexflow-agent.exe"
$webRoot = Join-Path $repoRoot "flutter\codexflow\build\web"
$dataDir = Join-Path $repoRoot "data"
$logDir = Join-Path $repoRoot "logs"
$agentPidFile = Join-Path $repoRoot "codexflow-agent.pid"
$webPidFile = Join-Path $repoRoot "codexflow-web.pid"
$stateDbPath = Join-Path $dataDir "codexflow-state.db"
$agentStdoutLog = Join-Path $logDir "agent.tailscale.stdout.log"
$agentStderrLog = Join-Path $logDir "agent.tailscale.stderr.log"
$webStdoutLog = Join-Path $logDir "web.tailscale.stdout.log"
$webStderrLog = Join-Path $logDir "web.tailscale.stderr.log"
$codexPath = "C:\Users\yehuaige\AppData\Roaming\npm\codex.cmd"
$agentAddr = "127.0.0.1:4319"
$webAddr = "127.0.0.1"
$webPort = 8088

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

function Get-TailscalePath {
    $command = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        "C:\Program Files\Tailscale\tailscale.exe",
        "C:\Program Files (x86)\Tailscale\tailscale.exe",
        "D:\software\Tailscale\tailscale.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Tailscale CLI was not found. Install Tailscale first."
}

function Stop-ProcessFromPidFile {
    param(
        [Parameter(Mandatory = $true)][string]$PidFile,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path $PidFile)) {
        return
    }

    $existingPid = (Get-Content $PidFile -Raw).Trim()
    if ($existingPid) {
        $existingProcess = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Write-Host "Stopping existing $Name process. PID=$existingPid"
            Stop-Process -Id $existingPid -Force
            Start-Sleep -Seconds 1
        }
    }

    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

function Start-Agent {
    if (-not (Test-Path $codexPath)) {
        throw "Missing codex command: $codexPath"
    }

    if (Test-AgentBinaryIsStale) {
        Build-AgentBinary
    }

    Stop-ProcessFromPidFile -PidFile $agentPidFile -Name "codexflow-agent"

    $env:CODEXFLOW_LISTEN_ADDR = $agentAddr
    $env:CODEXFLOW_CODEX_PATH = $codexPath
    $env:CODEXFLOW_STATE_DB_PATH = $stateDbPath

    $process = Start-Process `
        -FilePath $exePath `
        -WorkingDirectory $repoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $agentStdoutLog `
        -RedirectStandardError $agentStderrLog `
        -PassThru

    Start-Sleep -Seconds 3

    if ($process.HasExited) {
        throw "codexflow-agent exited early. Check logs in $logDir"
    }

    Set-Content -Path $agentPidFile -Value $process.Id
    Write-Host "codexflow-agent started on http://$agentAddr. PID=$($process.Id)"
}

function Start-Web {
    if (-not (Test-Path $webRoot -PathType Container)) {
        throw "Flutter Web build was not found: $webRoot"
    }

    Stop-ProcessFromPidFile -PidFile $webPidFile -Name "codexflow-web"

    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCommand) {
        throw "Python is required to serve Flutter Web build, but 'python' was not found in PATH"
    }

    $process = Start-Process `
        -FilePath $pythonCommand.Source `
        -ArgumentList @("-m", "http.server", "$webPort", "--bind", $webAddr) `
        -WorkingDirectory $webRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $webStdoutLog `
        -RedirectStandardError $webStderrLog `
        -PassThru

    Start-Sleep -Seconds 2

    if ($process.HasExited) {
        throw "codexflow-web exited early. Check logs in $logDir"
    }

    Set-Content -Path $webPidFile -Value $process.Id
    Write-Host "codexflow-web started on http://$webAddr`:$webPort. PID=$($process.Id)"
}

function Wait-HttpReady {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Process,
        [int]$MaxAttempts = 15,
        [int]$DelaySeconds = 2
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ($Process.HasExited) {
            throw "$Name exited before becoming healthy. Check logs in $logDir"
        }

        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 5
            return $response
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw "$Name did not become healthy after $MaxAttempts attempts: $Uri"
            }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Test-LocalEndpoints {
    $agentPid = (Get-Content $agentPidFile -Raw).Trim()
    $webPid = (Get-Content $webPidFile -Raw).Trim()
    $agentProcess = Get-Process -Id $agentPid -ErrorAction Stop
    $webProcess = Get-Process -Id $webPid -ErrorAction Stop

    $health = Wait-HttpReady -Uri "http://$agentAddr/healthz" -Name "codexflow-agent" -Process $agentProcess
    Write-Host "Agent health: $($health.StatusCode) $($health.Content)"

    $web = Wait-HttpReady -Uri "http://$webAddr`:$webPort/" -Name "codexflow-web" -Process $webProcess
    Write-Host "Web health: $($web.StatusCode)"
}

function Configure-TailscaleServe {
    $tailscalePath = Get-TailscalePath
    $statusOutput = & $tailscalePath status --json 2>&1
    $statusText = ($statusOutput | Out-String).Trim()
    $status = $null

    try {
        $status = $statusText | ConvertFrom-Json
    } catch {
        Write-Host "Could not parse Tailscale status:"
        Write-Host $statusText
        return
    }

    if ($status.BackendState -eq "NeedsLogin") {
        Write-Host "Tailscale is installed but logged out."
        if ($status.AuthURL) {
            Write-Host "Login URL: $($status.AuthURL)"
        }
        Write-Host "Open the login URL above, then rerun this script."
        return
    }

    if ($status.BackendState -ne "Running") {
        Write-Host "Tailscale backend state is '$($status.BackendState)'. Log in or resolve Tailscale health first, then rerun this script."
        return
    }

    & $tailscalePath serve --yes --bg --https 443 "http://$webAddr`:$webPort"
    & $tailscalePath serve --yes --bg --https 443 --set-path /api "http://$agentAddr/api"
    & $tailscalePath serve --yes --bg --https 443 --set-path /healthz "http://$agentAddr/healthz"

    Write-Host "Tailscale Serve configured for this node"
    & $tailscalePath serve status
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Start-Agent
Start-Web
Test-LocalEndpoints
Configure-TailscaleServe
