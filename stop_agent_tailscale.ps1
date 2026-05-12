$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentPidFile = Join-Path $repoRoot "codexflow-agent.pid"
$webPidFile = Join-Path $repoRoot "codexflow-web.pid"

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

function Stop-ProcessFromPidFile {
    param(
        [Parameter(Mandatory = $true)][string]$PidFile,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path $PidFile)) {
        Write-Host "No $Name PID file found."
        return
    }

    $existingPid = (Get-Content $PidFile -Raw).Trim()
    if ($existingPid) {
        $existingProcess = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($existingProcess) {
            Stop-Process -Id $existingPid -Force
            Write-Host "Stopped $Name. PID=$existingPid"
        } else {
            Write-Host "$Name PID=$existingPid was not running."
        }
    }

    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

$tailscalePath = Get-TailscalePath
if ($tailscalePath) {
    & $tailscalePath serve reset 2>$null
    Write-Host "Cleared Tailscale Serve config."
}

Stop-ProcessFromPidFile -PidFile $webPidFile -Name "codexflow-web"
Stop-ProcessFromPidFile -PidFile $agentPidFile -Name "codexflow-agent"
