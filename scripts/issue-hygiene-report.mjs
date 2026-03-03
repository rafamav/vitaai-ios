#!/usr/bin/env node

const GH_API_URL = process.env.GITHUB_API_URL || "https://api.github.com";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const REPO = process.env.GITHUB_REPOSITORY || "by-mav/pixio";
const STRICT = process.argv.includes("--strict");
const AUTOFIX_EVENT = process.argv.includes("--autofix-event");
const GITHUB_EVENT_PATH = process.env.GITHUB_EVENT_PATH || "";

if (!GITHUB_TOKEN) {
  console.error("[issue-hygiene] Missing GITHUB_TOKEN");
  process.exit(1);
}

const [owner, repo] = REPO.split("/");
if (!owner || !repo) {
  console.error(`[issue-hygiene] Invalid repository: ${REPO}`);
  process.exit(1);
}

async function ghRequest(path) {
  const response = await fetch(`${GH_API_URL}${path}`, {
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GitHub API ${response.status} ${path}: ${body}`);
  }

  return response.json();
}

function hasLabel(issue, prefix) {
  return issue.labels.some((label) => typeof label.name === "string" && label.name.startsWith(prefix));
}

function findMissingMetadata(issue) {
  const missing = [];
  if (!hasLabel(issue, "projeto:")) missing.push("projeto:*");
  if (!hasLabel(issue, "agente:")) missing.push("agente:*");
  if (!hasLabel(issue, "prioridade:")) missing.push("prioridade:*");
  if (!hasLabel(issue, "versao:")) missing.push("versao:*");
  return missing;
}

function isOpen(issue) {
  return issue.state === "open";
}

function isPR(item) {
  return Boolean(item.pull_request);
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

function repoDefaultProject(ownerName, repoName) {
  const slug = `${ownerName}/${repoName}`.toLowerCase();
  if (slug.includes("pixio")) return "projeto:pixio";
  if (slug.includes("vita")) return "projeto:vita.ai";
  if (slug.includes("ronaldinho")) return "projeto:ronaldinho-bot";
  if (slug.includes("slimfy")) return "projeto:slimfy-julia";
  return `projeto:${repoName.toLowerCase()}`;
}

async function ensureLabelExists(name, color, description) {
  const response = await fetch(`${GH_API_URL}/repos/${owner}/${repo}/labels`, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name, color, description }),
  });

  if (response.status === 201 || response.status === 422) {
    return;
  }

  const body = await response.text();
  throw new Error(`GitHub API ${response.status} label create failed for ${name}: ${body}`);
}

async function ensureEventIssueMetadata(issue) {
  const defaults = [
    { name: repoDefaultProject(owner, repo), color: "5319E7", description: "Projeto dono do item" },
    { name: "agente:TRIAGE", color: "C2E0C6", description: "Issue sem dono final, em triagem" },
    { name: "prioridade:media", color: "FBCA04", description: "Prioridade media (default)" },
    { name: "versao:pixio-backlog", color: "0E8A16", description: "Versao alvo/backlog do item" },
  ];

  for (const item of defaults) {
    await ensureLabelExists(item.name, item.color, item.description);
  }

  const current = issue.labels
    .map((label) => (typeof label.name === "string" ? label.name : ""))
    .filter(Boolean);

  const hasProject = current.some((name) => name.startsWith("projeto:"));
  const hasAgent = current.some((name) => name.startsWith("agente:"));
  const hasPriority = current.some((name) => name.startsWith("prioridade:"));
  const hasVersion = current.some((name) => name.startsWith("versao:"));

  const next = [...current];
  if (!hasProject) next.push(repoDefaultProject(owner, repo));
  if (!hasAgent) next.push("agente:TRIAGE");
  if (!hasPriority) next.push("prioridade:media");
  if (!hasVersion) next.push("versao:pixio-backlog");

  if (next.length === current.length) {
    return false;
  }

  await ghRequest(`/repos/${owner}/${repo}/issues/${issue.number}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ labels: next }),
  });
  return true;
}

async function main() {
  const eventPayload = await loadEventPayload();

  if (eventPayload?.issue && !isPR(eventPayload.issue)) {
    let issue = eventPayload.issue;
    let autofixed = false;
    if (AUTOFIX_EVENT) {
      autofixed = await ensureEventIssueMetadata(issue);
      if (autofixed) {
        issue = await ghRequest(`/repos/${owner}/${repo}/issues/${issue.number}`);
      }
    }

    const missing = findMissingMetadata(issue);
    const missingAssignee = !Array.isArray(issue.assignees) || issue.assignees.length === 0;

    console.log(`# Issue Hygiene Event Check (${owner}/${repo})`);
    console.log(`- Issue: #${issue.number} ${issue.title}`);
    console.log(`- Autofixed labels: ${autofixed ? "yes" : "no"}`);
    console.log(`- Missing metadata labels: ${missing.length > 0 ? missing.join(", ") : "none"}`);
    console.log(`- Missing assignee: ${missingAssignee ? "yes" : "no"}`);

    if (STRICT && missing.length > 0) {
      console.error("[issue-hygiene] strict event check failed");
      process.exit(2);
    }
    return;
  }

  const all = await ghRequest(`/repos/${owner}/${repo}/issues?state=open&per_page=100`);
  const issues = all.filter((item) => !isPR(item) && isOpen(item));
  const prs = all.filter((item) => isPR(item) && isOpen(item));

  const missingAgent = issues.filter((issue) => !hasLabel(issue, "agente:"));
  const missingPriority = issues.filter((issue) => !hasLabel(issue, "prioridade:"));
  const missingVersion = issues.filter((issue) => !hasLabel(issue, "versao:"));
  const missingProject = issues.filter((issue) => !hasLabel(issue, "projeto:"));
  const missingAssignee = issues.filter((issue) => !Array.isArray(issue.assignees) || issue.assignees.length === 0);

  console.log(`# Issue Hygiene Report (${owner}/${repo})`);
  console.log("");
  console.log(`- Open issues: ${issues.length}`);
  console.log(`- Open PRs: ${prs.length}`);
  console.log(`- Missing agent label: ${missingAgent.length}`);
  console.log(`- Missing priority label: ${missingPriority.length}`);
  console.log(`- Missing version label: ${missingVersion.length}`);
  console.log(`- Missing project label: ${missingProject.length}`);
  console.log(`- Missing assignee: ${missingAssignee.length}`);
  console.log("");

  if (missingAgent.length > 0) {
    console.log("## Missing `agente:*`");
    for (const issue of missingAgent.slice(0, 20)) {
      console.log(`- #${issue.number} ${issue.title}`);
    }
    console.log("");
  }

  if (missingPriority.length > 0) {
    console.log("## Missing `prioridade:*`");
    for (const issue of missingPriority.slice(0, 20)) {
      console.log(`- #${issue.number} ${issue.title}`);
    }
    console.log("");
  }

  if (missingVersion.length > 0) {
    console.log("## Missing `versao:*`");
    for (const issue of missingVersion.slice(0, 20)) {
      console.log(`- #${issue.number} ${issue.title}`);
    }
    console.log("");
  }

  if (missingProject.length > 0) {
    console.log("## Missing `projeto:*`");
    for (const issue of missingProject.slice(0, 20)) {
      console.log(`- #${issue.number} ${issue.title}`);
    }
    console.log("");
  }

  if (missingAssignee.length > 0) {
    console.log("## Missing assignee");
    for (const issue of missingAssignee.slice(0, 20)) {
      console.log(`- #${issue.number} ${issue.title}`);
    }
    console.log("");
  }

  if (STRICT && (missingAgent.length > 0 || missingPriority.length > 0 || missingVersion.length > 0 || missingProject.length > 0)) {
    console.error("[issue-hygiene] strict mode failed");
    process.exit(2);
  }
}

main().catch((error) => {
  console.error("[issue-hygiene] fatal", error instanceof Error ? error.message : error);
  process.exit(1);
});
