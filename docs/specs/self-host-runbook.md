# Spec: Self-host runbook (backend-only continuity)

**Status:** Stub  
**Linear:** CES-33

## Goal

Provide a practical continuity path so technical users can run backend services if managed hosting is unavailable.

## Scope (v1 continuity)

- Backend services only (API boundary, Postgres, auth boundary).
- No requirement for extra admin tooling in this phase.

## Minimum runbook artifacts

- `docker-compose` baseline for backend stack.
- `.env.example` with required variables and defaults where safe.
- Migration + seed commands.
- Backup/restore steps.
- Known limitations and troubleshooting notes.

## References

- [`adr/001-backend-api-boundary.md`](adr/001-backend-api-boundary.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
