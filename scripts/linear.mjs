#!/usr/bin/env node
/**
 * General-purpose Linear issue CLI for Cestovni agents.
 *
 * Lets an agent create, update, close, comment on, and read any Cestovni issue
 * over the Linear GraphQL API — the reusable complement to the one-shot
 * scripts/linear-*.mjs closeout/bootstrap scripts.
 *
 * Auth: LINEAR_API_KEY (env or .secrets/linear.env). See docs/linear/mcp-setup.md.
 *
 * Usage:
 *   node scripts/linear.mjs get <IDENTIFIER>
 *   node scripts/linear.mjs create --title "..." [--description "..."]
 *          [--description-file PATH] [--state Todo] [--labels type:bug,effort:low]
 *          [--priority 3] [--project Cestovni] [--team Cestovni]
 *   node scripts/linear.mjs update <IDENTIFIER> [--title ...] [--description ...]
 *          [--description-file PATH] [--state In Progress] [--labels ...] [--priority N]
 *   node scripts/linear.mjs close <IDENTIFIER> [--state Done] [--comment "..."]
 *   node scripts/linear.mjs comment <IDENTIFIER> --body "..." | --body-file PATH
 *
 * Priority: 0=None 1=Urgent 2=High 3=Normal 4=Low (Linear scale).
 * Exit codes: 0 ok, 1 runtime/API error, 2 usage error.
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");
const SECRET_FILE = join(REPO_ROOT, ".secrets", "linear.env");
const ENDPOINT = "https://api.linear.app/graphql";

const ALLOWED_SECRET_KEYS = new Set([
  "LINEAR_API_KEY",
  "LINEAR_TEAM_NAME",
  "LINEAR_PROJECT_NAME",
]);

function loadLocalSecretsFile() {
  if (!existsSync(SECRET_FILE)) return;
  let raw;
  try {
    raw = readFileSync(SECRET_FILE, "utf8");
  } catch {
    return;
  }
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    if (!ALLOWED_SECRET_KEYS.has(key)) continue;
    if (process.env[key] != null && process.env[key] !== "") continue;
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

loadLocalSecretsFile();

const USAGE = `Linear issue CLI (Cestovni)

Usage:
  node scripts/linear.mjs get <IDENTIFIER>
  node scripts/linear.mjs create --title "..." [options]
  node scripts/linear.mjs update <IDENTIFIER> [options]
  node scripts/linear.mjs close <IDENTIFIER> [--state Done] [--comment "..."]
  node scripts/linear.mjs comment <IDENTIFIER> --body "..." | --body-file PATH

Options (create/update):
  --title <str>              Issue title
  --description <str>        Issue body (markdown)
  --description-file <path>  Read body from a file (overrides --description)
  --state <name>            Workflow state name (e.g. Todo, In Progress, Done)
  --labels <a,b>            Comma-separated label names (e.g. type:bug,effort:low)
  --priority <0-4>          0 None, 1 Urgent, 2 High, 3 Normal, 4 Low
  --project <name>          Project name (default: Cestovni or $LINEAR_PROJECT_NAME)
  --team <name>             Team name (default: Cestovni or $LINEAR_TEAM_NAME)

Auth: LINEAR_API_KEY env var or .secrets/linear.env (see docs/linear/mcp-setup.md).`;

function parseArgs(argv) {
  const positional = [];
  const opts = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        opts[key] = true;
      } else {
        opts[key] = next;
        i++;
      }
    } else {
      positional.push(a);
    }
  }
  return { positional, opts };
}

function fail(msg, code = 1) {
  console.error(msg);
  process.exit(code);
}

async function gql(query, variables, token) {
  let res;
  try {
    res = await fetch(ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: token,
      },
      body: JSON.stringify({ query, variables }),
    });
  } catch (e) {
    throw new Error(`Network error reaching Linear: ${e.message}`);
  }
  let json;
  try {
    json = await res.json();
  } catch {
    throw new Error(`HTTP ${res.status}: non-JSON response from Linear`);
  }
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(json)}`);
  }
  if (json.errors?.length) {
    throw new Error(json.errors.map((e) => e.message).join("; "));
  }
  return json.data;
}

async function findIssue(token, identifier) {
  const data = await gql(
    `query ($id: String!) {
      issue(id: $id) {
        id identifier title url priority
        state { id name type }
        labels { nodes { id name } }
      }
    }`,
    { id: identifier },
    token,
  );
  return data.issue;
}

async function loadTeamContext(token, teamName, projectName) {
  const data = await gql(
    `query ($teamName: String!, $projectName: String!) {
      teams(filter: { name: { eq: $teamName } }) {
        nodes { id name states { nodes { id name type } } }
      }
      projects(filter: { name: { eq: $projectName } }) {
        nodes { id name }
      }
      issueLabels { nodes { id name } }
    }`,
    { teamName, projectName },
    token,
  );
  const team = data.teams?.nodes?.[0];
  if (!team) fail(`Team not found: ${teamName}`);
  const project = data.projects?.nodes?.[0] ?? null;
  const stateByName = Object.fromEntries(
    team.states.nodes.map((s) => [s.name.toLowerCase(), s]),
  );
  const labelByName = Object.fromEntries(
    data.issueLabels.nodes.map((l) => [l.name.toLowerCase(), l.id]),
  );
  return { team, project, stateByName, labelByName };
}

function resolveState(stateByName, name) {
  const s = stateByName[name.toLowerCase()];
  if (!s) {
    fail(
      `State not found: "${name}". Available: ` +
        Object.values(stateByName)
          .map((x) => x.name)
          .join(", "),
    );
  }
  return s.id;
}

function resolveLabels(labelByName, csv) {
  const names = csv
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const ids = [];
  for (const n of names) {
    const id = labelByName[n.toLowerCase()];
    if (!id) fail(`Label not found: "${n}". Create it in Linear first.`);
    ids.push(id);
  }
  return ids;
}

function resolvePriority(raw) {
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 0 || n > 4) {
    fail(`--priority must be an integer 0-4 (got "${raw}")`);
  }
  return n;
}

function bodyFromOpts(opts, fileKey, inlineKey) {
  if (opts[fileKey]) {
    const p = opts[fileKey];
    if (!existsSync(p)) fail(`--${fileKey} not found: ${p}`);
    return readFileSync(p, "utf8");
  }
  if (typeof opts[inlineKey] === "string") return opts[inlineKey];
  return undefined;
}

function printIssue(issue) {
  const labels = issue.labels?.nodes?.map((l) => l.name).join(", ") || "—";
  console.log(
    JSON.stringify(
      {
        identifier: issue.identifier,
        title: issue.title,
        state: issue.state?.name,
        priority: issue.priority,
        labels,
        url: issue.url,
      },
      null,
      2,
    ),
  );
}

async function cmdGet(token, positional) {
  const id = positional[0];
  if (!id) fail("get requires <IDENTIFIER>, e.g. CES-57", 2);
  const issue = await findIssue(token, id);
  if (!issue) fail(`Issue not found: ${id}`);
  printIssue(issue);
}

async function cmdCreate(token, opts) {
  const title = typeof opts.title === "string" ? opts.title : null;
  if (!title) fail("create requires --title", 2);
  const teamName = opts.team || process.env.LINEAR_TEAM_NAME || "Cestovni";
  const projectName =
    opts.project || process.env.LINEAR_PROJECT_NAME || "Cestovni";
  const ctx = await loadTeamContext(token, teamName, projectName);

  const input = { teamId: ctx.team.id, title };
  if (ctx.project) input.projectId = ctx.project.id;
  const description = bodyFromOpts(opts, "description-file", "description");
  if (description !== undefined) input.description = description;
  if (opts.state) input.stateId = resolveState(ctx.stateByName, opts.state);
  if (opts.labels) input.labelIds = resolveLabels(ctx.labelByName, opts.labels);
  if (opts.priority !== undefined)
    input.priority = resolvePriority(opts.priority);

  const data = await gql(
    `mutation ($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue { id identifier title url priority state { name } labels { nodes { name } } }
      }
    }`,
    { input },
    token,
  );
  if (!data.issueCreate?.success) fail("issueCreate returned success=false");
  console.log("Created:");
  printIssue(data.issueCreate.issue);
}

async function cmdUpdate(token, positional, opts) {
  const id = positional[0];
  if (!id) fail("update requires <IDENTIFIER>", 2);
  const teamName = opts.team || process.env.LINEAR_TEAM_NAME || "Cestovni";
  const projectName =
    opts.project || process.env.LINEAR_PROJECT_NAME || "Cestovni";
  const issue = await findIssue(token, id);
  if (!issue) fail(`Issue not found: ${id}`);

  const input = {};
  if (typeof opts.title === "string") input.title = opts.title;
  const description = bodyFromOpts(opts, "description-file", "description");
  if (description !== undefined) input.description = description;

  const needsCtx = opts.state || opts.labels;
  if (needsCtx) {
    const ctx = await loadTeamContext(token, teamName, projectName);
    if (opts.state) input.stateId = resolveState(ctx.stateByName, opts.state);
    if (opts.labels)
      input.labelIds = resolveLabels(ctx.labelByName, opts.labels);
  }
  if (opts.priority !== undefined)
    input.priority = resolvePriority(opts.priority);

  if (Object.keys(input).length === 0)
    fail("update needs at least one field (--title/--description/--state/--labels/--priority)", 2);

  const data = await gql(
    `mutation ($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue { id identifier title url priority state { name } labels { nodes { name } } }
      }
    }`,
    { id: issue.id, input },
    token,
  );
  if (!data.issueUpdate?.success) fail("issueUpdate returned success=false");
  console.log("Updated:");
  printIssue(data.issueUpdate.issue);
}

async function cmdClose(token, positional, opts) {
  const id = positional[0];
  if (!id) fail("close requires <IDENTIFIER>", 2);
  const stateName = typeof opts.state === "string" ? opts.state : "Done";
  const teamName = opts.team || process.env.LINEAR_TEAM_NAME || "Cestovni";
  const projectName =
    opts.project || process.env.LINEAR_PROJECT_NAME || "Cestovni";
  const issue = await findIssue(token, id);
  if (!issue) fail(`Issue not found: ${id}`);
  const ctx = await loadTeamContext(token, teamName, projectName);
  const stateId = resolveState(ctx.stateByName, stateName);

  if (typeof opts.comment === "string" && opts.comment.trim()) {
    await gql(
      `mutation ($input: CommentCreateInput!) {
        commentCreate(input: $input) { success }
      }`,
      { input: { issueId: issue.id, body: opts.comment } },
      token,
    );
    console.log("Posted comment.");
  }

  const data = await gql(
    `mutation ($id: String!, $stateId: String!) {
      issueUpdate(id: $id, input: { stateId: $stateId }) {
        success
        issue { id identifier title url priority state { name } labels { nodes { name } } }
      }
    }`,
    { id: issue.id, stateId },
    token,
  );
  if (!data.issueUpdate?.success) fail("issueUpdate returned success=false");
  console.log(`Closed → ${stateName}:`);
  printIssue(data.issueUpdate.issue);
}

async function cmdComment(token, positional, opts) {
  const id = positional[0];
  if (!id) fail("comment requires <IDENTIFIER>", 2);
  const body = bodyFromOpts(opts, "body-file", "body");
  if (!body || !body.trim())
    fail("comment requires --body or --body-file", 2);
  const issue = await findIssue(token, id);
  if (!issue) fail(`Issue not found: ${id}`);
  const data = await gql(
    `mutation ($input: CommentCreateInput!) {
      commentCreate(input: $input) { success comment { id url } }
    }`,
    { input: { issueId: issue.id, body } },
    token,
  );
  if (!data.commentCreate?.success) fail("commentCreate returned success=false");
  console.log(`Commented on ${issue.identifier}: ${data.commentCreate.comment?.url ?? "ok"}`);
}

async function main() {
  const [, , command, ...rest] = process.argv;
  if (!command || command === "help" || command === "--help") {
    console.log(USAGE);
    process.exit(command ? 0 : 2);
  }

  const token = process.env.LINEAR_API_KEY?.trim();
  if (!token) {
    fail(
      "Missing LINEAR_API_KEY. Set it in .secrets/linear.env or the environment.\n" +
        "See docs/linear/mcp-setup.md.",
    );
  }

  const { positional, opts } = parseArgs(rest);

  switch (command) {
    case "get":
      return cmdGet(token, positional);
    case "create":
      return cmdCreate(token, opts);
    case "update":
      return cmdUpdate(token, positional, opts);
    case "close":
      return cmdClose(token, positional, opts);
    case "comment":
      return cmdComment(token, positional, opts);
    default:
      fail(`Unknown command: ${command}\n\n${USAGE}`, 2);
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
