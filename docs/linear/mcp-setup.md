# Linear MCP + API setup (all environments)

**Team / project:** Cestovni / Cestovni  
**GraphQL API:** `https://api.linear.app/graphql` (scripts)  
**MCP endpoint:** `https://mcp.linear.app/mcp` (Cursor agents)

Agents and scripts need Linear access to mark issues **Done**, create follow-ups, and post status comments. Use **one** of the paths below per environment.

---

## 1. Cursor Desktop (recommended for MCP)

1. Open **Cursor Settings → MCP** (or install from the [Linear MCP link](https://cursor.com/docs/context/mcp)).
2. Enable the **Linear** server and complete the OAuth sign-in when prompted.
3. Verify: in chat, ask the agent to `get_issue` for a known id (e.g. `CES-57`). Tools should list `get_issue`, `save_issue`, etc. — not `needsAuth`.

**Works:** interactive OAuth via `cursor://anysphere.cursor-mcp/oauth/callback` (registered on Linear’s side for desktop).

---

## 2. Cursor Cloud Agents & Automations (MCP)

Cloud agents use a **different** OAuth callback (`https://www.cursor.com/agents/mcp/oauth/callback`). Until Cursor + Linear register that URI, native MCP auth in cloud runs may show **`needsAuth`** or **Invalid redirect URI** even when desktop auth works.

**Workarounds (pick one):**

| Approach | When to use |
| -------- | ----------- |
| **A. `LINEAR_API_KEY` + scripts** | Reliable today for cloud agents and CI — see [§3](#3-api-key-scripts-fallback-all-environments) |
| **B. Desktop MCP only** | Human-driven sessions in the local IDE |
| **C. Wait for cloud OAuth fix** | Track [Cursor forum thread](https://forum.cursor.com/t/cant-authenticate-linear-mcp-in-automation-cloud-agents/159268) |

**Cloud environment secret (recommended for agents):**

1. Linear → **Settings → Account → Security & Access** → create a **Personal API key** (write access for issue updates).
2. Cursor → **Dashboard → Cloud → Environments** → your environment → **Secrets** → add `LINEAR_API_KEY`.
3. Re-run the agent; use `node scripts/linear-ces57-closeout.mjs` (or future `scripts/linear-*.mjs`) when MCP still reports `needsAuth`.

Linear also supports passing an API key on the MCP `Authorization: Bearer` header ([Linear MCP FAQ](https://linear.app/docs/mcp)); Cursor does not yet expose custom MCP headers in cloud UI — prefer **§3** until that lands.

---

## 3. API key + scripts (fallback, all environments)

Same key file as [saved-views.md](./saved-views.md):

```bash
mkdir -p .secrets && cp .secrets.example/linear.env .secrets/linear.env
chmod 600 .secrets/linear.env
# Edit .secrets/linear.env — set LINEAR_API_KEY=lin_api_...
```

**One-shot closeout after CES-57 merge (mark Done + create M1 follow-up):**

```bash
node scripts/linear-ces57-closeout.mjs
```

Re-running is safe: the script skips creating a duplicate follow-up if one already exists.

**Bootstrap views/templates (once per workspace):**

```bash
node scripts/linear-workspace-bootstrap.mjs
```

**General create/update/close (reusable, any issue):**

```bash
node scripts/linear.mjs get CES-57
node scripts/linear.mjs create --title "..." --description "..." --state Todo --labels type:improvement,effort:medium
node scripts/linear.mjs update CES-57 --state "In Progress" --priority 2
node scripts/linear.mjs close CES-57 --comment "Shipped in PR #NN"
node scripts/linear.mjs comment CES-57 --body-file notes.md
```

This is the reusable complement to the one-shot `linear-*.mjs` scripts — use it for
autonomous create/update/close when MCP is `needsAuth`. Same `LINEAR_API_KEY` auth.

Never commit `.secrets/linear.env` or paste keys into issues/PRs.

---

## 4. Verification checklist

| Environment | MCP `get_issue` | `node scripts/linear-*.mjs` |
| ----------- | ----------------- | ----------------------------- |
| Cursor Desktop | OAuth in MCP settings | `.secrets/linear.env` or `export LINEAR_API_KEY` |
| Cloud Agent | May be `needsAuth` until cloud OAuth ships | Set `LINEAR_API_KEY` in environment secrets |
| Local terminal / CI | N/A | `export LINEAR_API_KEY` or `.secrets/linear.env` |

---

## Related

- [issue-templates.md](./issue-templates.md) — issue body shape for `/create-issue`
- [saved-views.md](./saved-views.md) — views + bootstrap script
- [delivery-plan-v1.md](../product/delivery-plan-v1.md) — M1/M-dist tracking
