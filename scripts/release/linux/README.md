# CodexFlow Linux Host

This bundle contains:

- `codexflow-agent`: the local Go agent for Linux amd64
- `codexflow-agent.json`: local config file, defaulting to `0.0.0.0:4318`
- `web/`: bundled CodexFlow Web UI served by the agent

## Ubuntu Quick Start

Install the Codex CLI on the Ubuntu host first, then unpack this bundle:

```bash
tar -xzf codexflow-linux-host-<version>.tar.gz
cd codexflow-linux-host
chmod +x ./codexflow-agent
./codexflow-agent
```

Open the printed browser URL from the same machine, or the printed LAN URL from a phone on the same network.

## Configuration

To change the listen address, edit `codexflow-agent.json`:

```json
{
  "listenAddr": "0.0.0.0:4318"
}
```

Useful environment overrides:

```bash
CODEXFLOW_CODEX_PATH=/usr/local/bin/codex ./codexflow-agent
CODEXFLOW_STATE_DB_PATH="$HOME/.codexflow/state.db" ./codexflow-agent
CODEXFLOW_WEB_ROOT=/path/to/web ./codexflow-agent
```

The bundled Web UI is served by `codexflow-agent` itself on port `4318`.

## Stop

Press `Ctrl+C` in the terminal that launched the agent, or stop the process with your process manager.
