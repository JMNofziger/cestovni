#!/usr/bin/env node
/**
 * One-shot bootstrap: team cycles + Cestovni custom views + issue templates.
 * Requires a Personal API Key: https://linear.app/settings/api
 *
 *   export LINEAR_API_KEY="lin_api_..."
 *   node scripts/linear-workspace-bootstrap.mjs
 *
 * Optional: LINEAR_TEAM_NAME (default Cestovni), LINEAR_PROJECT_NAME (default Cestovni)
 */

const ENDPOINT = "https://api.linear.app/graphql";
const TEAM_NAME = process.env.LINEAR_TEAM_NAME || "Cestovni";
const PROJECT_NAME = process.env.LINEAR_PROJECT_NAME || "Cestovni";

const BUG_TEMPLATE_BODY = String.raw`### TL;DR

- 

### Current behavior

- 

### Expected outcome

- 

### Acceptance / verification

- [ ] Repro steps documented
- [ ] Fixed when: 

### Relevant files (max 3)

- 
- 
- 

### Risks / notes

- None

### Spec

\`docs/specs/...\` or TBD

### Out of scope

- 
`;

const FEATURE_TEMPLATE_BODY = String.raw`### TL;DR

- 

### Current state

- 

### Expected outcome

- 

### Acceptance criteria

- [ ] 
- [ ] 

### Relevant files (max 3)

- 
- 
- 

### Risks / notes

- None

### Spec

\`docs/specs/...\`

### Out of scope

- 
`;

const IMPROVEMENT_TEMPLATE_BODY = String.raw`### TL;DR

- 

### Current state

- 

### Expected outcome

- 

### Acceptance criteria

- [ ] 
- [ ] 

### Relevant files (max 3)

- 
- 
- 

### Risks / notes

- None

### Spec

\`docs/specs/...\` or N/A

### Out of scope

- 
`;

const SPIKE_TEMPLATE_BODY = String.raw`### TL;DR

- 

### Question

- 

### Done when

- [ ] Question answered / time-box respected
- [ ] Findings linked or summarized for follow-up issues

### Relevant files (max 3)

- N/A

### Risks / notes

- None

### Spec

TBD — spike has no spec yet

### Out of scope

- 
`;

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

async function main() {
  const token = process.env.LINEAR_API_KEY;
  if (!token?.trim()) {
    console.error(
      "Missing LINEAR_API_KEY. Create one at Linear → Settings → API → Personal API keys.",
    );
    process.exit(1);
  }

  const setupQuery = `
    query Bootstrap($teamName: String!, $projectName: String!) {
      teams(filter: { name: { eq: $teamName } }) {
        nodes {
          id
          name
          cyclesEnabled
          cycleDuration
          states {
            nodes { id name type }
          }
        }
      }
      projects(filter: { name: { eq: $projectName } }) {
        nodes { id name }
      }
      issueLabels(filter: { name: { eq: "type:bug" } }) {
        nodes { id name }
      }
    }
  `;

  const data = await gql(
    setupQuery,
    { teamName: TEAM_NAME, projectName: PROJECT_NAME },
    token,
  );

  const team = data.teams?.nodes?.[0];
  if (!team) {
    console.error(`Team not found: ${TEAM_NAME}`);
    process.exit(1);
  }
  const project = data.projects?.nodes?.[0];
  if (!project) {
    console.error(`Project not found: ${PROJECT_NAME}`);
    process.exit(1);
  }
  const bugLabelId = data.issueLabels?.nodes?.[0]?.id;

  const stateByName = Object.fromEntries(
    team.states.nodes.map((s) => [s.name, s.id]),
  );

  const backlogId = stateByName["Backlog"];
  const todoId = stateByName["Todo"];
  const inProgressId = stateByName["In Progress"];
  const inReviewId = stateByName["In Review"];
  for (const [label, id] of [
    ["Backlog", backlogId],
    ["Todo", todoId],
    ["In Progress", inProgressId],
    ["In Review", inReviewId],
  ]) {
    if (!id) console.warn(`Warning: workflow state "${label}" not found on team.`);
  }

  if (!team.cyclesEnabled) {
    await gql(
      `mutation ($id: String!, $input: TeamUpdateInput!) {
        teamUpdate(id: $id, input: $input) { success }
      }`,
      {
        id: team.id,
        input: {
          cyclesEnabled: true,
          cycleDuration: 2,
          cycleStartDay: 0,
        },
      },
      token,
    );
    console.log("Enabled 2-week cycles for team", team.name);
  } else {
    console.log("Cycles already enabled for team", team.name);
  }

  const projectFilter = { project: { id: { eq: project.id } } };

  /** @type {{ name: string; filterData: Record<string, unknown> }[]} */
  const views = [];
  if (backlogId) {
    views.push({
      name: "Cestovni — Backlog",
      filterData: { ...projectFilter, state: { id: { eq: backlogId } } },
    });
  }
  if (todoId) {
    views.push({
      name: "Cestovni — Ready",
      filterData: { ...projectFilter, state: { id: { eq: todoId } } },
    });
  }
  if (inProgressId) {
    views.push({
      name: "Cestovni — Active",
      filterData: { ...projectFilter, state: { id: { eq: inProgressId } } },
    });
  }
  if (inReviewId) {
    views.push({
      name: "Cestovni — In review",
      filterData: { ...projectFilter, state: { id: { eq: inReviewId } } },
    });
  }
  if (bugLabelId) {
    views.push({
      name: "Cestovni — Bugs",
      filterData: {
        ...projectFilter,
        labels: { some: { id: { eq: bugLabelId } } },
      },
    });
  }
  views.push({
    name: "Cestovni — Current cycle",
    filterData: { ...projectFilter, cycle: { isActive: { eq: true } } },
  });

  for (const v of views) {
    try {
      await gql(
        `mutation ($input: CustomViewCreateInput!) {
          customViewCreate(input: $input) {
            success
            customView { id name }
          }
        }`,
        {
          input: {
            name: v.name,
            teamId: team.id,
            shared: true,
            filterData: v.filterData,
          },
        },
        token,
      );
      console.log("Created view:", v.name);
    } catch (e) {
      const msg = String(e.message || e);
      if (/unique|already exists|duplicate/i.test(msg)) {
        console.log("Skip view (exists):", v.name);
      } else {
        console.error("View failed:", v.name, msg);
      }
    }
  }

  const backlogState = backlogId;
  const baseIssueTemplate = {
    teamId: team.id,
    projectId: project.id,
    ...(backlogState ? { stateId: backlogState } : {}),
    priority: 3,
  };

  const templates = [
    {
      name: "Bug",
      description: BUG_TEMPLATE_BODY,
      labelIds: bugLabelId ? [bugLabelId] : undefined,
    },
    { name: "Feature", description: FEATURE_TEMPLATE_BODY },
    { name: "Improvement", description: IMPROVEMENT_TEMPLATE_BODY },
    { name: "Spike", description: SPIKE_TEMPLATE_BODY },
  ];

  for (const t of templates) {
    const templateData = {
      ...baseIssueTemplate,
      title: "",
      description: t.description,
      ...(t.labelIds ? { labelIds: t.labelIds } : {}),
    };
    try {
      await gql(
        `mutation ($input: TemplateCreateInput!) {
          templateCreate(input: $input) { success template { id } }
        }`,
        {
          input: {
            name: t.name,
            type: "issue",
            teamId: team.id,
            templateData,
          },
        },
        token,
      );
      console.log("Created template:", t.name);
    } catch (e) {
      const msg = String(e.message || e);
      if (/unique|already exists|duplicate/i.test(msg)) {
        console.log("Skip template (exists):", t.name);
      } else {
        console.error("Template failed:", t.name, msg);
      }
    }
  }

  console.log("Done. Pin views in Linear sidebar if needed.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
