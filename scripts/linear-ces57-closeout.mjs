#!/usr/bin/env node
/**
 * Post-merge closeout for CES-57 (settings prefs + default_vehicle_id).
 *
 * - Marks CES-57 Done (if not already)
 * - Posts a summary comment on CES-57
 * - Creates M1 follow-up issue for Log/History prefs display (if missing)
 *
 * Requires LINEAR_API_KEY — see docs/linear/mcp-setup.md
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");
const SECRET_FILE = join(REPO_ROOT, ".secrets", "linear.env");
const ENDPOINT = "https://api.linear.app/graphql";
const TEAM_NAME = process.env.LINEAR_TEAM_NAME || "Cestovni";
const PROJECT_NAME = process.env.LINEAR_PROJECT_NAME || "Cestovni";

const FOLLOW_UP_TITLE =
  "Wire Log/History to settings prefs for unit display (CES-57 follow-on)";

const FOLLOW_UP_BODY = `### TL;DR

- Log and History still hardcode km/L/EUR for labels and conversion; Settings now persists prefs (**CES-57**, PR #9, schema v3).
- Read \`SettingsRepository.watchSingle()\` and apply \`preferred_distance_unit\`, \`preferred_volume_unit\`, \`currency_code\`, and \`timezone\` on display + entry conversion in \`log_page.dart\` / \`history_page.dart\`.

### Current state

- **CES-57 shipped:** Settings UI + \`default_vehicle_id\` column + cold-start seeding in \`shell.dart#_seedActiveVehicle\` (merged PR #9).
- **Gap:** Log/History do not yet consume the stored prefs — still assume km/L/EUR defaults.

### Expected outcome

- Log form labels and History row formatting respect cached settings (distance/volume/currency).
- Canonical storage unchanged (INT64 SI units per \`DATA_CONTRACTS.md\`).
- Widget tests cover at least one non-default pref path (e.g. mi/gal or CZK).

### Acceptance criteria

- [ ] Log odometer/volume labels follow \`settings.preferred_distance_unit\` / \`preferred_volume_unit\`
- [ ] History list/detail price + unit formatting follows settings
- [ ] Default currency on new fill-ups follows \`settings.currency_code\` (no per-fill-up override — out of scope)
- [ ] \`flutter test\` green; no regression to \`validateInsert\` / SI storage

### Relevant files (max 3)

- \`client/lib/app/pages/log_page.dart\`
- \`client/lib/app/pages/history_page.dart\`
- \`client/lib/consumption/adapters.dart\` (reuse existing conversion helpers)

### Risks / notes

- Android default timezone remains \`UTC\` vs PWA-lite \`Europe/Prague\` — pre-existing cross-surface mismatch; do not reconcile without product sign-off.
- Per-fill-up currency override is **CES-60** (if tracked separately) — out of scope here.

### Spec

\`docs/product/ux/DATA_CONTRACTS.md\` §"Units and storage" + \`docs/specs/data-model.md\` §\`settings\`

### UX refs

\`docs/product/ux/cestovni-views.md\` §Log / History

### Out of scope

- Settings UI (CES-57 — done)
- Metrics/Maint tabs, photo pipeline (CES-40)
`;

const CES57_COMMENT = `**CES-57 closeout (repo)** — merged via PR #9 (\`7530fc0\` on \`main\`).

**Shipped**
- Schema v3: nullable \`settings.default_vehicle_id\` (migration \`0003_settings_default_vehicle_id\`)
- Settings Preferences UI: distance/volume/currency/timezone + default vehicle picker
- \`shell.dart#_seedActiveVehicle\` prefers default vehicle when still live

**Follow-on (M1)**
- Log/History still need to *read* prefs for display/conversion — tracked as a child follow-up issue (created by \`scripts/linear-ces57-closeout.mjs\` if absent).

**MCP note:** Cloud agents may still show Linear MCP \`needsAuth\`; use \`docs/linear/mcp-setup.md\` + \`LINEAR_API_KEY\` until cloud OAuth callback is registered.`;

function loadLocalSecretsFile() {
  if (!existsSync(SECRET_FILE)) return;
  const raw = readFileSync(SECRET_FILE, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    if (key !== "LINEAR_API_KEY") continue;
    if (process.env.LINEAR_API_KEY) continue;
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env.LINEAR_API_KEY = value;
  }
}

loadLocalSecretsFile();

async function gql(query, variables, token) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: token,
    },
    body: JSON.stringify({ query, variables }),
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(json)}`);
  }
  if (json.errors?.length) {
    throw new Error(json.errors.map((e) => e.message).join("; "));
  }
  return json.data;
}

async function findIssueByIdentifier(token, identifier) {
  const data = await gql(
    `query ($id: String!) {
      issue(id: $id) { id identifier title state { id name } url }
    }`,
    { id: identifier },
    token,
  );
  return data.issue;
}

async function findFollowUpIssue(token, teamId) {
  const data = await gql(
    `query ($teamId: ID!, $title: String!) {
      issues(
        filter: {
          team: { id: { eq: $teamId } }
          title: { eq: $title }
        }
        first: 1
      ) {
        nodes { id identifier title url }
      }
    }`,
    { teamId, title: FOLLOW_UP_TITLE },
    token,
  );
  return data.issues?.nodes?.[0] ?? null;
}

async function main() {
  const token = process.env.LINEAR_API_KEY?.trim();
  if (!token) {
    console.error(
      "Missing LINEAR_API_KEY. See docs/linear/mcp-setup.md\n" +
        "  .secrets/linear.env  or  export LINEAR_API_KEY=lin_api_...",
    );
    process.exit(1);
  }

  const setup = await gql(
    `query ($teamName: String!, $projectName: String!) {
      teams(filter: { name: { eq: $teamName } }) {
        nodes {
          id
          states { nodes { id name type } }
        }
      }
      projects(filter: { name: { eq: $projectName } }) {
        nodes { id }
      }
      issueLabels {
        nodes { id name }
      }
    }`,
    { teamName: TEAM_NAME, projectName: PROJECT_NAME },
    token,
  );

  const team = setup.teams?.nodes?.[0];
  const project = setup.projects?.nodes?.[0];
  if (!team) {
    console.error(`Team not found: ${TEAM_NAME}`);
    process.exit(1);
  }
  if (!project) {
    console.error(`Project not found: ${PROJECT_NAME}`);
    process.exit(1);
  }

  const doneState = team.states.nodes.find((s) => s.name === "Done");
  const todoState = team.states.nodes.find((s) => s.name === "Todo");
  const labelByName = Object.fromEntries(
    setup.issueLabels.nodes.map((l) => [l.name, l.id]),
  );
  const improvementLabel = labelByName["type:improvement"];
  const effortMedium = labelByName["effort:medium"];

  const ces57 = await findIssueByIdentifier(token, "CES-57");
  if (!ces57) {
    console.error("CES-57 not found — check team key / access.");
    process.exit(1);
  }
  console.log(`Found ${ces57.identifier}: ${ces57.title} (${ces57.state.name})`);

  if (ces57.state.name !== "Done" && doneState) {
    await gql(
      `mutation ($id: String!, $stateId: String!) {
        issueUpdate(id: $id, input: { stateId: $stateId }) { success }
      }`,
      { id: ces57.id, stateId: doneState.id },
      token,
    );
    console.log("Marked CES-57 → Done");
  } else if (ces57.state.name === "Done") {
    console.log("CES-57 already Done — skip state update");
  } else {
    console.warn("Done state not found — skipped CES-57 state update");
  }

  await gql(
    `mutation ($input: CommentCreateInput!) {
      commentCreate(input: $input) { success }
    }`,
    { input: { issueId: ces57.id, body: CES57_COMMENT } },
    token,
  );
  console.log("Posted closeout comment on CES-57");

  let followUp = await findFollowUpIssue(token, team.id);
  if (followUp) {
    console.log(
      `Follow-up already exists: ${followUp.identifier} — ${followUp.url}`,
    );
  } else {
    const labelIds = [improvementLabel, effortMedium].filter(Boolean);
    const input = {
      teamId: team.id,
      projectId: project.id,
      title: FOLLOW_UP_TITLE,
      description: FOLLOW_UP_BODY,
      stateId: todoState?.id,
      labelIds: labelIds.length ? labelIds : undefined,
    };
    const created = await gql(
      `mutation ($input: IssueCreateInput!) {
        issueCreate(input: $input) {
          success
          issue { id identifier url }
        }
      }`,
      { input },
      token,
    );
    followUp = created.issueCreate.issue;
    console.log(`Created follow-up: ${followUp.identifier} — ${followUp.url}`);

    if (ces57.id) {
      await gql(
        `mutation ($input: IssueRelationCreateInput!) {
          issueRelationCreate(input: $input) { success }
        }`,
        {
          input: {
            issueId: followUp.id,
            relatedIssueId: ces57.id,
            type: "blocks",
          },
        },
        token,
      ).catch(() => {
        // Relation API may differ; non-fatal
      });
    }
  }

  console.log("\nDone. Update delivery-plan-v1.md if a new identifier was created.");
  if (followUp?.identifier) {
    console.log(`Follow-up Linear id: ${followUp.identifier}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
