# CodexFlow Docs

`docs/` is the durable knowledge base for CodexFlow.
Root files provide entry, architecture, and plan routing; detailed notes live here.

## Routing

- To understand overall system boundaries: read `../ARCHITECTURE.md`
- To inspect detailed runtime architecture notes: read `architecture.md`
- To understand session states and transitions: read `session-lifecycle.md`
- To inspect product direction: read `product-roadmap.md`
- To reason about Claude Code support: read `claude-integration-feasibility.md`
- To inspect UI prototypes and visual references: read `ui_references/README.md`
- To work with complex plans: read `exec-plans/README.md`
- To change documentation structure or writing style: read `standards/documentation_principles.md`

## Knowledge Layers

- `architecture.md`
  - detailed runtime architecture notes
- `session-lifecycle.md`
  - session state model and lifecycle design
- `product-roadmap.md`
  - product direction and phased capability targets
- `claude-integration-feasibility.md`
  - Claude Code integration feasibility and constraints
- `ui_references/`
  - HTML prototypes, screenshots, and visual reference material
- `exec-plans/`
  - active plans, completed plans, and technical debt
- `standards/`
  - stable documentation and engineering conventions

## Maintenance Principles

- Keep stable knowledge in `docs/`.
- Keep root files short and route-focused.
- Keep temporary execution detail in `docs/exec-plans/`.
- Move long-lived conclusions from completed plans back into stable docs only when they remain useful.

