# CodexFlow Windows Host Bundle

This bundle is the easiest way to host CodexFlow on a Windows machine.

## Included

- `codexflow-agent.exe`: the local Go agent
- `web/`: bundled Flutter Web client served directly by the agent

## Prerequisites

- Windows
- Codex CLI installed and logged in

## Quick Start

1. Extract the zip anywhere you want.
2. Double-click `codexflow-agent.exe`, or launch it from PowerShell:

```powershell
.\codexflow-agent.exe
```

3. Open one of these in a browser or client:

```text
http://127.0.0.1:4318
http://<your-lan-ip>:4318
```

4. If you also want automatic Tailscale Serve wiring, run:
4. Copy one of the printed addresses into CodexFlow `Settings > Agent Address`.

Typical addresses:

```text
Local: http://127.0.0.1:4318
LAN:   http://192.168.31.147:4318
```

## Notes

- LAN address is for devices on the same local network.
- The bundled Web UI is served by `codexflow-agent.exe` itself on port `4318`.
- Logs are written into `logs/`.
- Local state is stored in `data/`.
- If you want Tailscale access, configure `tailscale serve` yourself to point at `http://127.0.0.1:4318`.

## Stop

Close the console window that launched the agent, or stop `codexflow-agent.exe` from Task Manager.
