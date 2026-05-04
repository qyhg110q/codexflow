# CodexFlow AGENTS

## Project Positioning

CodexFlow is a control plane for local AI coding agents.
It connects Codex CLI and Claude Code runtimes to mobile, web, and desktop clients through a local Go Agent.

The project goal is not remote terminal viewing. It is structured session control: dashboards, approvals, timelines, diffs, plans, prompts, steering, interrupts, and future relay / pairing.

## First Read Order

1. `README.md`
2. `ARCHITECTURE.md`
3. `PLANS.md`
4. `docs/README.md`
5. Related `docs/exec-plans/active/*.md`
6. Related design docs under `docs/`
7. UI references under `docs/ui_references/`

## Task Routing

- To understand repository structure, runtime boundaries, and client / agent layering: read `ARCHITECTURE.md`
- To understand current work and when to create an ExecPlan: read `PLANS.md`
- To inspect detailed protocol and lifecycle notes: read `docs/architecture.md` and `docs/session-lifecycle.md`
- To reason about Claude Code integration: read `docs/claude-integration-feasibility.md`
- To inspect product direction: read `docs/product-roadmap.md`
- To work on Android / mobile UI direction: read `docs/ui_references/android_mobile/README.md`
- To run a multi-step task that spans code, docs, packaging, or validation: create or update `docs/exec-plans/active/*.md`
- To change documentation structure or writing conventions: read `docs/standards/documentation_principles.md`

## Repository Map

- `cmd/codexflow-agent/`: Go Agent entry point
- `internal/codex/`: Codex app-server protocol adapter
- `internal/runtime/`: session, approval, runtime, and dashboard orchestration
- `internal/httpapi/`: HTTP API, SSE, image upload, and client-facing surface
- `internal/store/`: local state persistence
- `ios/CodexFlow/`: SwiftUI iOS client
- `flutter/codexflow/`: Flutter cross-platform client
- `docs/`: stable architecture, product, lifecycle, UI reference, and execution docs
- `assets/`: screenshots and README assets
- `scripts/`: project helper scripts

## Working Constraints

- Keep `AGENTS.md` as an entry and routing file. Put durable details in `docs/`.
- Keep root `ARCHITECTURE.md` focused on system boundaries and recommended evolution.
- Keep root `PLANS.md` focused on plan routing and active / completed plan index.
- Use `docs/exec-plans/` for complex work that needs handoff.
- Code changes should include at least one relevant build, test, or targeted validation when practical.
- UI changes should include a screenshot, visual check, or explicit acceptance checklist when practical.
- Avoid committing local runtime artifacts such as `.tooling/`, `logs/`, `*.pid`, generated binaries, and local build outputs unless the task explicitly asks for them.
