# Session Lifecycle

## Goal

CodexFlow presents every discovered session as continuable.

The UI should not ask the user to understand whether a session is currently
managed, attached, loaded, or history-only. Those are runtime implementation
details. From the user's point of view, opening a session and sending a prompt
is the continuation path.

Internally, the agent still tracks history and runtime separately:

- History answers: what happened before
- Runtime answers: what process can execute the next turn

## User Model

Every visible session has one of two user-facing states:

1. `continuable`
   - The session is visible and can receive the next prompt
   - If no runtime is currently attached, the agent prepares one before starting
     the turn

2. `archived`
   - The session is hidden from local CodexFlow surfaces
   - Upstream history is preserved when the source agent keeps it

Ending a session is no longer a barrier to continuing later. It stops the
current runtime relationship and leaves the history visible. A later prompt can
prepare a runtime again.

## Runtime Model

Backend lifecycle fields such as `managed`, `runtime_available`,
`history_only`, and `ended` may still exist for compatibility and diagnostics.
They must not gate the normal continue composer.

Before starting a turn, the agent ensures runtime readiness:

### Codex

1. If the thread is already loaded, start the turn directly.
2. If the thread is not loaded or was ended locally, call `thread/resume`.
3. Mark the session loaded/managed internally.
4. Start the requested turn.

### Claude

1. If a live SDK session exists, start the turn directly.
2. If a runtime session id is known, try to resume that runtime.
3. If resume fails or only transcript history exists, open a new Claude runtime
   from that history representation.
4. Store the resulting runtime binding and start the requested turn.

Claude transcript ids and runtime session ids remain separate.

## UI Rules

- Show the composer for every visible session detail.
- Let the first send action prepare runtime automatically.
- Do not show a required attach/resume/takeover step.
- Keep archive as the explicit action for removing a session from local
  surfaces.
- Keep interrupt and approval controls tied to the currently running turn.

## API Compatibility

`POST /api/v1/sessions/:id/resume` remains available for older clients and
manual recovery, but new clients should not require it before sending a prompt.
