#!/usr/bin/env node

const LINEAR_API_URL = "https://api.linear.app/graphql";
const GH_API_URL = process.env.GITHUB_API_URL || "https://api.github.com";

const LINEAR_API_KEY = process.env.LINEAR_API_KEY;
const LINEAR_TEAM_KEY = process.env.LINEAR_TEAM_KEY || "BYM";
const LINEAR_PROJECT_ID = process.env.LINEAR_PROJECT_ID || "";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPOSITORY = process.env.GITHUB_REPOSITORY;
const GITHUB_EVENT_NAME = process.env.GITHUB_EVENT_NAME || "";
const GITHUB_EVENT_PATH = process.env.GITHUB_EVENT_PATH || "";
const MAX_AUDIT_ISSUES = Number(process.env.LINEAR_SYNC_MAX_ISSUES || "200");

if (!LINEAR_API_KEY) {
  console.error("[linear-sync] Missing LINEAR_API_KEY");
  process.exit(1);
}

if (!GITHUB_TOKEN) {
  console.error("[linear-sync] Missing GITHUB_TOKEN");
  process.exit(1);
}

if (!GITHUB_REPOSITORY || !GITHUB_REPOSITORY.includes("/")) {
  console.error("[linear-sync] Missing or invalid GITHUB_REPOSITORY");
  process.exit(1);
}

const [ghOwner, ghRepo] = GITHUB_REPOSITORY.split("/");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function linearRequest(query, variables = {}) {
  const response = await fetch(LINEAR_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: LINEAR_API_KEY,
    },
    body: JSON.stringify({ query, variables }),
  });

  if (!response.ok) {
    throw new Error(`Linear API HTTP ${response.status}`);
  }

  const json = await response.json();
  if (json.errors?.length) {
    throw new Error(`Linear API error: ${json.errors.map((error) => error.message).join(" | ")}`);
  }

  return json.data;
}

async function ghRequest(path, init = {}) {
  const response = await fetch(`${GH_API_URL}${path}`, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "X-GitHub-Api-Version": "2022-11-28",
      ...(init.headers || {}),
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GitHub API ${response.status} ${path}: ${body}`);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

function parseMarkers(body) {
  if (!body) {
    return { linearIssueId: null, linearIdentifier: null };
  }

  const idMatch = body.match(/<!--\s*linearIssueId:([\w-]+)\s*-->/i);
  const identifierMatch = body.match(/<!--\s*linearIdentifier:([A-Z]+-\d+)\s*-->/i);

  return {
    linearIssueId: idMatch?.[1] || null,
    linearIdentifier: identifierMatch?.[1] || null,
  };
}

function extractIssueBody(issue) {
  return issue.body || "";
}

function findLabelValue(issue, prefix) {
  const label = issue.labels.find(
    (item) => typeof item.name === "string" && item.name.toLowerCase().startsWith(prefix.toLowerCase()),
  );
  if (!label) {
    return null;
  }
  return label.name.slice(prefix.length).trim() || null;
}

function getProjectName(issue) {
  return findLabelValue(issue, "projeto:") || ghRepo.toUpperCase();
}

function getVersionTag(issue) {
  return findLabelValue(issue, "versao:") || issue.milestone?.title || "backlog";
}

function getAgentName(issue) {
  return findLabelValue(issue, "agente:") || "unassigned";
}

function mapPriority(labels) {
  const names = labels.map((label) => label.name.toLowerCase());

  if (
    names.some(
      (name) =>
        name.includes("critical") ||
        name.includes("critica") ||
        name.includes("urgent") ||
        name.includes("urgente") ||
        name.includes("p0") ||
        name.includes("sev0") ||
        name.includes("prioridade:critica")
    )
  ) {
    return 1;
  }
  if (
    names.some(
      (name) =>
        name.includes("high") ||
        name.includes("alta") ||
        name.includes("p1") ||
        name.includes("sev1") ||
        name.includes("prioridade:alta")
    )
  ) {
    return 2;
  }
  if (
    names.some(
      (name) =>
        name.includes("medium") ||
        name.includes("media") ||
        name.includes("média") ||
        name.includes("normal") ||
        name.includes("p2") ||
        name.includes("sev2")
    )
  ) {
    return 3;
  }
  if (
    names.some(
      (name) =>
        name.includes("low") ||
        name.includes("baixa") ||
        name.includes("p3") ||
        name.includes("sev3")
    )
  ) {
    return 4;
  }

  return 0;
}

function parsePositiveNumber(rawValue, fallback) {
  const parsed = Number(rawValue);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

const SLA_DAYS_BY_PRIORITY = {
  1: parsePositiveNumber(process.env.LINEAR_SLA_DAYS_URGENT, 1),
  2: parsePositiveNumber(process.env.LINEAR_SLA_DAYS_HIGH, 3),
  3: parsePositiveNumber(process.env.LINEAR_SLA_DAYS_MEDIUM, 7),
  4: parsePositiveNumber(process.env.LINEAR_SLA_DAYS_LOW, 14),
};

function computeSlaDueDate(priority, issueCreatedAt) {
  const slaDays = SLA_DAYS_BY_PRIORITY[priority];
  if (!slaDays) {
    return null;
  }

  const createdAt = issueCreatedAt ? new Date(issueCreatedAt) : new Date();
  if (Number.isNaN(createdAt.getTime())) {
    return null;
  }

  const due = new Date(createdAt);
  due.setUTCDate(due.getUTCDate() + slaDays);
  return due.toISOString().slice(0, 10);
}

function buildLinearInput(issue, teamId) {
  const priority = mapPriority(issue.labels);
  const dueDate = computeSlaDueDate(priority, issue.created_at);

  const input = {
    title: `[${ghOwner}/${ghRepo}] ${issue.title}`,
    description: buildLinearDescription(issue),
    priority,
    dueDate,
  };

  if (teamId) {
    input.teamId = teamId;
  }

  return input;
}

function buildLinearDescription(issue) {
  const labels = issue.labels.map((label) => label.name).join(", ") || "none";
  const reporter = issue.user?.login || "unknown";
  const project = getProjectName(issue);
  const version = getVersionTag(issue);
  const agent = getAgentName(issue);

  return [
    `GitHub issue mirror for ${GITHUB_REPOSITORY}#${issue.number}`,
    "",
    `- GitHub URL: ${issue.html_url}`,
    `- Reporter: @${reporter}`,
    `- Project: ${project}`,
    `- Version: ${version}`,
    `- Agent owner: ${agent}`,
    `- Labels: ${labels}`,
    "",
    "## Original body",
    issue.body || "(empty)",
  ].join("\n");
}

function buildIterationLogComment(issue, action, senderLogin) {
  const timestamp = new Date().toISOString();
  const project = getProjectName(issue);
  const version = getVersionTag(issue);
  const agent = getAgentName(issue);
  const actor = senderLogin || "unknown";

  return [
    "### Iteration Log",
    `- Timestamp: ${timestamp}`,
    `- Project: ${project}`,
    `- Version: ${version}`,
    `- Issue: #${issue.number}`,
    `- Action: ${action || "sync"}`,
    `- Agent owner: ${agent}`,
    `- Actor: @${actor}`,
    `- Source: ${issue.html_url}`,
  ].join("\n");
}

async function getTeamContext(teamKey) {
  const data = await linearRequest(
    `query TeamByKey($key: String!) {
      teams(filter: { key: { eq: $key } }) {
        nodes {
          id
          key
          name
          states {
            nodes {
              id
              name
              type
            }
          }
        }
      }
    }`,
    { key: teamKey },
  );

  const team = data.teams.nodes[0];
  if (!team) {
    throw new Error(`Linear team not found for key ${teamKey}`);
  }

  const doneState = team.states.nodes.find((state) => state.type === "completed");
  const todoState = team.states.nodes.find((state) => state.type === "unstarted");

  return {
    teamId: team.id,
    doneStateId: doneState?.id || null,
    todoStateId: todoState?.id || null,
  };
}

async function findLinearIssueByUrl(url) {
  const data = await linearRequest(
    `query FindByUrl($url: String!) {
      issues(filter: { url: { eq: $url } }, first: 1) {
        nodes {
          id
          identifier
          url
          state { id type }
        }
      }
    }`,
    { url },
  );

  return data.issues.nodes[0] || null;
}

async function getLinearIssueById(id) {
  const data = await linearRequest(
    `query IssueById($id: String!) {
      issue(id: $id) {
        id
        identifier
        url
        state { id type }
      }
    }`,
    { id },
  );

  return data.issue || null;
}

async function createLinearIssue(issue, teamId) {
  const input = {
    ...buildLinearInput(issue, teamId),
    url: issue.html_url,
  };

  if (LINEAR_PROJECT_ID) {
    input.projectId = LINEAR_PROJECT_ID;
  }

  const data = await linearRequest(
    `mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          url
        }
      }
    }`,
    { input },
  );

  if (!data.issueCreate.success || !data.issueCreate.issue) {
    throw new Error("Linear issueCreate failed");
  }

  return data.issueCreate.issue;
}

async function updateLinearIssue(linearIssueId, issue) {
  const input = buildLinearInput(issue);

  const data = await linearRequest(
    `mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
      }
    }`,
    {
      id: linearIssueId,
      input,
    },
  );

  if (!data.issueUpdate.success) {
    throw new Error(`Linear issueUpdate failed for ${linearIssueId}`);
  }
}

async function transitionLinearIssue(linearIssueId, stateId) {
  if (!stateId) {
    return;
  }

  const data = await linearRequest(
    `mutation TransitionIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
      }
    }`,
    {
      id: linearIssueId,
      input: {
        stateId,
      },
    },
  );

  if (!data.issueUpdate.success) {
    throw new Error(`Linear transition failed for ${linearIssueId}`);
  }
}

async function createLinearComment(linearIssueId, body) {
  const data = await linearRequest(
    `mutation CommentCreate($input: CommentCreateInput!) {
      commentCreate(input: $input) {
        success
        comment { id }
      }
    }`,
    {
      input: {
        issueId: linearIssueId,
        body,
      },
    },
  );

  if (!data.commentCreate.success) {
    throw new Error(`Linear commentCreate failed for ${linearIssueId}`);
  }
}

function withMarkers(originalBody, markerIssueId, markerIdentifier, markerUrl) {
  const cleanBody = (originalBody || "").replace(/\n?<!--\s*linearIssueId:[\w-]+\s*-->/gi, "").replace(/\n?<!--\s*linearIdentifier:[A-Z]+-\d+\s*-->/gi, "").trimEnd();

  return [
    cleanBody,
    "",
    `<!-- linearIssueId:${markerIssueId} -->`,
    `<!-- linearIdentifier:${markerIdentifier} -->`,
    `\nLinked Linear issue: ${markerUrl}`,
  ]
    .join("\n")
    .trim();
}

async function updateGitHubIssueBody(issueNumber, body) {
  await ghRequest(`/repos/${ghOwner}/${ghRepo}/issues/${issueNumber}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ body }),
  });
}

async function ensureLinearMirror(issue, teamContext) {
  const markers = parseMarkers(extractIssueBody(issue));

  if (markers.linearIssueId) {
    const existing = await getLinearIssueById(markers.linearIssueId);
    if (existing) {
      return existing;
    }
  }

  const fromUrl = await findLinearIssueByUrl(issue.html_url);
  if (fromUrl) {
    const nextBody = withMarkers(issue.body || "", fromUrl.id, fromUrl.identifier, fromUrl.url);
    if (nextBody !== (issue.body || "")) {
      await updateGitHubIssueBody(issue.number, nextBody);
    }
    return fromUrl;
  }

  const created = await createLinearIssue(issue, teamContext.teamId);
  const nextBody = withMarkers(issue.body || "", created.id, created.identifier, created.url);
  await updateGitHubIssueBody(issue.number, nextBody);
  return created;
}

function isPullRequestIssue(issue) {
  return Boolean(issue.pull_request);
}

async function syncSingleIssue(issue, action, teamContext, eventContext = null) {
  if (!issue || isPullRequestIssue(issue)) {
    return { skipped: true };
  }

  const linearIssue = await ensureLinearMirror(issue, teamContext);

  if (action === "closed") {
    await transitionLinearIssue(linearIssue.id, teamContext.doneStateId);
    if (eventContext?.enabled) {
      await createLinearComment(linearIssue.id, buildIterationLogComment(issue, action, eventContext.sender));
    }
    return { synced: true, linearIdentifier: linearIssue.identifier, action: "closed" };
  }

  if (action === "reopened") {
    await transitionLinearIssue(linearIssue.id, teamContext.todoStateId);
    if (eventContext?.enabled) {
      await createLinearComment(linearIssue.id, buildIterationLogComment(issue, action, eventContext.sender));
    }
    return { synced: true, linearIdentifier: linearIssue.identifier, action: "reopened" };
  }

  await updateLinearIssue(linearIssue.id, issue);
  if (eventContext?.enabled) {
    await createLinearComment(linearIssue.id, buildIterationLogComment(issue, action, eventContext.sender));
  }
  return { synced: true, linearIdentifier: linearIssue.identifier, action: action || "upsert" };
}

async function listOpenGithubIssues() {
  const issues = [];
  let page = 1;

  while (issues.length < MAX_AUDIT_ISSUES) {
    const result = await ghRequest(
      `/repos/${ghOwner}/${ghRepo}/issues?state=open&per_page=100&page=${page}&sort=updated&direction=desc`,
    );

    if (!Array.isArray(result) || result.length === 0) {
      break;
    }

    for (const issue of result) {
      if (!isPullRequestIssue(issue)) {
        issues.push(issue);
      }
      if (issues.length >= MAX_AUDIT_ISSUES) {
        break;
      }
    }

    if (result.length < 100) {
      break;
    }

    page += 1;
    await sleep(120);
  }

  return issues;
}

async function loadEventPayload() {
  if (!GITHUB_EVENT_PATH) {
    return null;
  }

  try {
    const fs = await import("node:fs/promises");
    const raw = await fs.readFile(GITHUB_EVENT_PATH, "utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function main() {
  const payload = await loadEventPayload();
  const teamContext = await getTeamContext(LINEAR_TEAM_KEY);

  if (payload?.issue) {
    const action = payload.action || "";
    const result = await syncSingleIssue(payload.issue, action, teamContext, {
      enabled: true,
      sender: payload.sender?.login || null,
    });
    console.log("[linear-sync] event sync result", result);
    return;
  }

  const openIssues = await listOpenGithubIssues();
  let synced = 0;
  let skipped = 0;

  for (const issue of openIssues) {
    try {
      await syncSingleIssue(issue, "audit", teamContext);
      synced += 1;
    } catch (error) {
      skipped += 1;
      console.warn(`[linear-sync] failed issue #${issue.number}:`, error instanceof Error ? error.message : error);
    }
  }

  console.log(`[linear-sync] audit completed synced=${synced} skipped=${skipped} total=${openIssues.length}`);
}

main().catch((error) => {
  console.error("[linear-sync] fatal", error instanceof Error ? error.stack : error);
  process.exit(1);
});
