$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $repoRoot "codexflow-agent.exe"
$webRoot = Join-Path $repoRoot "flutter\codexflow\build\web"
$dataDir = Join-Path $repoRoot "data"
$logDir = Join-Path $repoRoot "logs"
$agentPidFile = Join-Path $repoRoot "codexflow-agent.pid"
$webPidFile = Join-Path $repoRoot "codexflow-web.pid"
$stateDbPath = Join-Path $dataDir "codexflow-state.db"
$agentStdoutLog = Join-Path $logDir "agent.user.stdout.log"
$agentStderrLog = Join-Path $logDir "agent.user.stderr.log"
$webStdoutLog = Join-Path $logDir "web.user.stdout.log"
$webStderrLog = Join-Path $logDir "web.user.stderr.log"
$codexPath = "C:\Users\yehuaige\AppData\Roaming\npm\codex.cmd"
$agentPort = 4318
$webPort = 8088
$agentListenAddr = "0.0.0.0:$agentPort"
$webListenAddr = "0.0.0.0"
$tailscaleProxyHost = "127.0.0.1"

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

    return $null
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
        Where-Object { $_.InterfaceAlias -match "WLAN|Wi-Fi|WiFi|Ethernet" } |
        Sort-Object ConnectivityRank, InterfaceMetric |
        Select-Object -First 1
    if ($preferred) {
        return $preferred.IPAddress
    }

    $fallback = $candidates | Sort-Object ConnectivityRank, InterfaceMetric | Select-Object -First 1
    if ($fallback) {
        return $fallback.IPAddress
    }

    return $null
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
            Write-Host ("Stopping existing {0} process. PID={1}" -f $Name, $existingPid)
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

    $env:CODEXFLOW_LISTEN_ADDR = $agentListenAddr
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
    return $process
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
        -ArgumentList @("-m", "http.server", "$webPort", "--bind", $webListenAddr) `
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
    return $process
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
            throw ("{0} exited before becoming healthy. Check logs in {1}" -f $Name, $logDir)
        }

        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 5
            return $response
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw ("{0} did not become healthy after {1} attempts: {2}" -f $Name, $MaxAttempts, $Uri)
            }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Test-LocalEndpoints {
    param(
        [Parameter(Mandatory = $true)]$AgentProcess,
        [Parameter(Mandatory = $true)]$WebProcess
    )

    $health = Wait-HttpReady -Uri "http://127.0.0.1:$agentPort/healthz" -Name "codexflow-agent" -Process $AgentProcess
    $web = Wait-HttpReady -Uri "http://127.0.0.1:$webPort/" -Name "codexflow-web" -Process $WebProcess

    return [PSCustomObject]@{
        AgentStatus = $health.StatusCode
        AgentBody = $health.Content
        WebStatus = $web.StatusCode
    }
}

function Configure-TailscaleServe {
    $tailscalePath = Get-TailscalePath
    if (-not $tailscalePath) {
        return [PSCustomObject]@{
            Available = $false
            Configured = $false
            Message = "Tailscale CLI not found. Skipping tailnet URL."
            Url = $null
        }
    }

    $statusOutput = & $tailscalePath status --json 2>&1
    $statusText = ($statusOutput | Out-String).Trim()

    try {
        $status = $statusText | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            Available = $true
            Configured = $false
            Message = "Could not parse Tailscale status. Skipping tailnet URL."
            Url = $null
        }
    }

    if ($status.BackendState -eq "NeedsLogin") {
        return [PSCustomObject]@{
            Available = $true
            Configured = $false
            Message = "Tailscale is installed but logged out. Run Tailscale login first."
            Url = $null
        }
    }

    if ($status.BackendState -ne "Running") {
        return [PSCustomObject]@{
            Available = $true
            Configured = $false
            Message = ("Tailscale backend state is '{0}'." -f $status.BackendState)
            Url = $null
        }
    }

    & $tailscalePath serve --yes --bg --https 443 "http://$tailscaleProxyHost`:$webPort" | Out-Null
    & $tailscalePath serve --yes --bg --https 443 --set-path /api "http://$tailscaleProxyHost`:$agentPort/api" | Out-Null
    & $tailscalePath serve --yes --bg --https 443 --set-path /healthz "http://$tailscaleProxyHost`:$agentPort/healthz" | Out-Null

    $dnsName = $null
    if ($status.Self -and $status.Self.DNSName) {
        $dnsName = $status.Self.DNSName.TrimEnd('.')
    }

    $url = if ($dnsName) { "https://$dnsName" } else { $null }
    return [PSCustomObject]@{
        Available = $true
        Configured = $true
        Message = "Tailscale Serve configured."
        Url = $url
    }
}

function Test-TailscaleEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl
    )

    $health = Invoke-WebRequest -Uri ("{0}/healthz" -f $BaseUrl) -UseBasicParsing -TimeoutSec 10
    return [PSCustomObject]@{
        Status = $health.StatusCode
        Body = $health.Content
    }
}

function Write-AccessSummary {
    param(
        [string]$LanIp,
        [string]$TailscaleUrl,
        [string]$TailscaleMessage
    )

    Write-Host ""
    Write-Host "CodexFlow is ready."
    Write-Host ""
    Write-Host "Use these URLs directly in CodexFlow Settings > Agent Address:"
    if ($LanIp) {
        Write-Host "LAN:       http://$LanIp`:$agentPort"
    } else {
        Write-Host "LAN:       unavailable (could not detect LAN IPv4)"
    }

    if ($TailscaleUrl) {
        Write-Host "Tailscale: $TailscaleUrl"
    } else {
        Write-Host "Tailscale: unavailable"
    }

    Write-Host ""
    Write-Host "Optional browser access:"
    if ($LanIp) {
        Write-Host "LAN Web:       http://$LanIp`:$webPort"
    }
    if ($TailscaleUrl) {
        Write-Host "Tailscale Web: $TailscaleUrl"
    }

    Write-Host ""
    Write-Host "Local health:"
    Write-Host "Agent: http://127.0.0.1:$agentPort/healthz"
    Write-Host "Web:   http://127.0.0.1:$webPort/"

    if ($TailscaleMessage) {
        Write-Host ""
        Write-Host "Tailscale note: $TailscaleMessage"
    }
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$agentProcess = Start-Agent
$webProcess = Start-Web
$localCheck = Test-LocalEndpoints -AgentProcess $agentProcess -WebProcess $webProcess
$tailscale = Configure-TailscaleServe

$lanIp = Get-LanIpAddress
$tailscaleCheck = $null
if ($tailscale.Url) {
    $tailscaleCheck = Test-TailscaleEndpoint -BaseUrl $tailscale.Url
}

Write-Host ("Agent health: {0} {1}" -f $localCheck.AgentStatus, $localCheck.AgentBody)
Write-Host ("Web health: {0}" -f $localCheck.WebStatus)
if ($tailscaleCheck) {
    Write-Host ("Tailscale health: {0} {1}" -f $tailscaleCheck.Status, $tailscaleCheck.Body)
}

Write-AccessSummary -LanIp $lanIp -TailscaleUrl $tailscale.Url -TailscaleMessage $tailscale.Message
