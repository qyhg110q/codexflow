# CodexFlow Windows Host Bundle

This bundle is the easiest way to host CodexFlow on a Windows machine.

## Included

- `codexflow-agent.exe`: the local Go agent
- `web/`: bundled Flutter Web client
- `start_codexflow.ps1`: one-click startup for LAN and Tailscale
- `stop_codexflow.ps1`: stop agent, web server, and Tailscale Serve mapping

## Prerequisites

- Windows
- Codex CLI installed and logged in
- Python available in `PATH`
- Tailscale installed and logged in if you want tailnet access

## Quick Start

1. Extract the zip anywhere you want.
2. Open PowerShell in the extracted folder.
3. Run:

```powershell
.\start_codexflow.ps1
```

4. Copy one of the printed addresses into CodexFlow `Settings > Agent Address`.

Typical output:

```text
LAN:       http://192.168.31.147:4318
Tailscale: https://your-machine.your-tailnet.ts.net
```

## Notes

- LAN address is for devices on the same local network.
- Tailscale address is for devices in the same tailnet.
- The script also serves the bundled Web UI on port `8088`.
- Logs are written into `logs/`.
- Local state is stored in `data/`.

## Stop

```powershell
.\stop_codexflow.ps1
```

This stops the local processes and clears Tailscale Serve routes created by the start script.
