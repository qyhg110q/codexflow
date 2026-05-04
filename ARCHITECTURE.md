# CodexFlow Architecture

## Goal

CodexFlow turns local AI coding agent runtimes into a controllable application layer.
The core architecture separates agent runtime ownership from client UI, so mobile and web clients can manage sessions without scraping terminals or speaking raw CLI protocols.

The system should optimize for three things:

- Runtime clarity: Codex, Claude Code, and future agents have explicit adapter boundaries
- Client stability: iOS, Flutter, Android, Web, and desktop clients consume one stable HTTP / SSE API
- Operational safety: approvals, interrupts, steering, relay, pairing, and audit can converge in the Go Agent

## Minimal Target Structure

```text
codexflow/
  AGENTS.md
  README.md
  ARCHITECTURE.md
  PLANS.md
  cmd/
    codexflow-agent/
  internal/
    codex/
    runtime/
    httpapi/
    store/
  ios/
    CodexFlow/
  flutter/
    codexflow/
  docs/
    README.md
    architecture.md
    session-lifecycle.md
    product-roadmap.md
    claude-integration-feasibility.md
    standards/
    ui_references/
    exec-plans/
      README.md
      active/
      completed/
      tech-debt/
```

## Documentation Boundaries

- `AGENTS.md`: project entry, reading order, task routing, and hard constraints
- `ARCHITECTURE.md`: stable system shape, layers, ownership boundaries, and recommended evolution
- `PLANS.md`: plan mechanism, current active plans, and recent completed work
- `docs/README.md`: docs knowledge base navigation
- `docs/architecture.md`: detailed runtime architecture notes
- `docs/session-lifecycle.md`: session state and lifecycle rules
- `docs/product-roadmap.md`: product direction and staged capability targets
- `docs/claude-integration-feasibility.md`: Claude Code integration notes
- `docs/ui_references/`: HTML prototypes, screenshots, and visual references
- `docs/exec-plans/`: active plans, completed plans, and tracked technical debt
- `docs/standards/`: documentation and engineering conventions

## Runtime Layers

### 1. Agent Adapters

Agent adapters convert external runtimes into internal CodexFlow events and operations.

- `internal/codex/` owns Codex app-server protocol integration
- Claude Code integration is modeled separately in runtime code and feasibility docs
- Future adapters should expose the same application-level concepts: sessions, turns, events, approvals, diffs, and prompts

### 2. Runtime Orchestration

`internal/runtime/` is the application brain.
It owns session inventory, managed runtime state, history import, live runtime attachment, approval queues, turn control, dashboard aggregation, and event fan-out.

Runtime logic should stay independent from any specific UI client.

### 3. HTTP And Event API

`internal/httpapi/` exposes stable client-facing APIs.
Clients should not rely on raw Codex or Claude protocol details.

The current surface includes health checks, dashboard, sessions, approvals, turn actions, image upload, and SSE events.

### 4. Local State

`internal/store/` persists local state such as managed sessions and archive status.
State should support reconnect, restart, and future relay / pairing without forcing clients to infer lifecycle from transcripts.

### 5. Clients

- `ios/CodexFlow/`: native SwiftUI iOS client
- `flutter/codexflow/`: cross-platform client for Android, Web, desktop, and future shared UI work

Clients are responsible for presentation and interaction flow.
They should treat the Go Agent API as the source of truth.

## Recommended Evolution

1. Stabilize session lifecycle and runtime state vocabulary across Codex and Claude Code.
2. Make SSE refresh reliable enough that dashboards and approvals feel live.
3. Consolidate Flutter as the main cross-platform client while keeping iOS native work available for platform-specific experiments.
4. Add secure pairing, authentication, and relay before exposing CodexFlow outside a trusted LAN or tailnet.
5. Introduce policy and audit capabilities for approvals, automatic actions, and high-risk commands.

