# Exec Plans

`docs/exec-plans/` is for complex work that needs continuity.
The directories describe lifecycle state rather than topic.

## Directories

- `active/`
  - plans currently being executed or likely to be resumed
- `completed/`
  - finished plans with validation and retrospective notes
- `tech-debt/`
  - known structural issues that need tracking but are not active work

## Lifecycle

1. Create an ExecPlan under `active/` when a complex task starts.
2. Update the same document as work progresses.
3. Move the plan to `completed/` when the task lands.
4. Record deferred structural issues in `tech-debt/`.

## Writing Requirements

ExecPlans are working documents, not approval memos.
They should help a later agent continue without rereading the whole project.

Each plan should record:

- current status and goal
- scope and out-of-scope boundaries
- progress checkpoints
- discoveries and surprises
- decisions and tradeoffs
- validation evidence
- outcome and retrospective

## Validation Evidence

- Keep small evidence in the plan, such as command summaries and acceptance checks.
- Put large artifacts in `artifacts/` or a clearly referenced project path.
- Link or name the relevant artifacts from the plan.

