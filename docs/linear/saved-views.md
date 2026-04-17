# Linear saved views (Cestovni)

**Canonical repo (GitHub `main`):** https://github.com/JMNofziger/cestovni — root [README.md](https://github.com/JMNofziger/cestovni/blob/main/README.md) links product docs, specs, and this Linear project.

Your team uses these **issue states**: Backlog, Todo, In Progress, In Review, Done (+ Canceled, Duplicate).

## Automated (recommended)

From repo root, with a [Personal API key](https://linear.app/settings/api):

**Preferred — key stays local (gitignored under `.secrets/`):**

```bash
mkdir -p .secrets && cp .secrets.example/linear.env .secrets/linear.env
chmod 600 .secrets/linear.env
# Edit .secrets/linear.env and set LINEAR_API_KEY (never commit this file)
node scripts/linear-workspace-bootstrap.mjs
```

**One-off (shell session only):**

```bash
export LINEAR_API_KEY="lin_api_..."
node scripts/linear-workspace-bootstrap.mjs
```

That script also enables **2-week cycles** for team `Cestovni` (if they were off) and creates workspace **issue templates** (Bug, Feature, Improvement, Spike). Re-running is safe: existing views/templates are skipped when Linear reports a duplicate.

## Manual

Create **saved views** in Linear (Issues → filters → **Save as view**). Every view must include **Project = Cestovni** so other products never leak in.


| View name                    | Filters / notes                                                                                                             |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Cestovni — Backlog**       | Project **Cestovni** + Status **Backlog**; sort by priority                                                                 |
| **Cestovni — Ready**         | Project **Cestovni** + Status **Todo** (ready to pick up)                                                                   |
| **Cestovni — Active**        | Project **Cestovni** + Status **In Progress**                                                                               |
| **Cestovni — In review**     | Project **Cestovni** + Status **In Review**                                                                                 |
| **Cestovni — Bugs**          | Project **Cestovni** + Label **type:bug**                                                                                   |
| **Cestovni — Current cycle** | Project **Cestovni** + **Current cycle** *(enable cycles for team **Cestovni** in Linear settings if this filter is empty)* |


Pin or favorite these views in the sidebar.

## Optional: cycles

If **Cestovni — Current cycle** is useless until cycles exist: **Team settings → Cycles** → turn on and pick length (e.g. 2 weeks).