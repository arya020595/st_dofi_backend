# AGENTS.md

Coding rules for this repository — for any AI agent (Codex, Claude Code, or otherwise) and any
human contributor — live in [`CLAUDE.md`](CLAUDE.md) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

Read and follow both files before writing or modifying code. They are the single source of truth for:

- The layered architecture (Controller → Policy/Service → Query → Model, Controller → Blueprint) and what belongs in each layer.
- SOLID conventions as applied to this codebase.
- Style/lint/security/test requirements (Rubocop, Brakeman, bundler-audit, Minitest) and the definition of done.

Do not duplicate or restate these rules here — treat `CLAUDE.md` and `docs/ARCHITECTURE.md` as
authoritative and keep this file as a pointer only, so the two docs never drift out of sync.
