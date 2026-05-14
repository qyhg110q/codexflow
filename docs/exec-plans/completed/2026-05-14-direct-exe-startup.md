# Status

Completed.

# Goal

Make the Windows-hosted CodexFlow server start directly from `codexflow-agent.exe` so users do not need a PowerShell startup script for the normal launch path.

# Scope

- Analyze whether the current script-only startup flow can be collapsed into the Go agent safely.
- Move required startup responsibilities from PowerShell into the Go binary where practical.
- Let the agent serve bundled Web assets itself when a nearby `web/` directory is present.
- Update release packaging and docs so direct exe startup is the primary path.
- Validate with targeted Go tests and a local Windows build.

Out of scope:

- Auth, pairing, or relay redesign.
- Reworking Flutter client behavior.

# Progress

- 2026-05-14: Read workspace rules and project routing docs, then inspected `codexflow` startup scripts, release packaging, Go config, runtime startup, and HTTP server boundaries.
- 2026-05-14: Confirmed the current PowerShell launchers mainly provide startup orchestration: codex path selection, listen/state env vars, web static hosting, local health checks, Tailscale setup, and PID/log management.
- 2026-05-14: Determined the direct exe goal is feasible because the core runtime already lives inside the Go agent; the missing pieces are startup defaults and bundled web serving.
- 2026-05-14: Implemented direct exe startup in the Go agent: auto-detected Codex path, runtime layout defaults, bundled web serving on the same HTTP listener, and startup access logging.
- 2026-05-14: Removed user-facing startup helper scripts from the repo and from release bundle packaging so `codexflow-agent.exe` is the only normal runtime entry point.
- 2026-05-14: Updated Windows host and source-build docs to describe direct exe launch and manual Tailscale configuration.

# Surprises & Discoveries

- The original release bundle depended on Python only for serving static web assets; once the Go agent served `web/` itself, the startup scripts became structurally unnecessary.
- The Go agent already owns the only HTTP listener, so folding static file serving into it is structurally straightforward.
- The repository has unrelated dirty changes in generated Flutter plugin files and helper scripts, so this task should avoid those surfaces.

# Decision Log

- Direct exe startup should become the primary happy path for the Windows host bundle.
- User-facing startup helper scripts should be removed entirely rather than retained as optional wrappers.
- Bundled web hosting should use the same Go HTTP server instead of a second Python process.

# Validation

- `go test ./internal/config ./internal/httpapi`
- `go build -o codexflow-agent.exe ./cmd/codexflow-agent`
- `powershell -ExecutionPolicy Bypass -File .\build_release_assets.ps1 -SkipApk -SkipWeb -SkipAgentBuild`
- Packaged bundle smoke check:
  - launch `artifacts/release/v0.1.0/codexflow-windows-host/codexflow-agent.exe`
  - `Invoke-WebRequest http://127.0.0.1:4318/healthz`
  - `Invoke-WebRequest http://127.0.0.1:4318/`

# Outcomes & Retrospective

- `codexflow-agent.exe` now works as a single-process Windows host entry point when bundled with `web/`.
- Release packaging and docs now match that runtime model instead of the previous PowerShell + Python two-process flow.
