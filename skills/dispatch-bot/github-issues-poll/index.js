// github-issues-poll — OpenClaw custom skill for dispatch-bot
//
// Polls GitHub Issues across both orgs, triages unassigned issues,
// and assigns them to the appropriate specialist bot.
//
// Uses `gh` CLI (via OpenClaw exec tool) — no API token handling needed,
// gh is already authenticated via deploy-bot.sh.

const ORGS = ["Oss-Gruppen-AS", "Bot-Fleet-Inc"];
const ASSIGNEE = "botfleet-dispatch";

const DOMAIN_MAP = {
  architecture: { bot: "botfleet-archi", label: "bot:archi" },
  code: { bot: "botfleet-coding", label: "bot:coding" },
  infrastructure: { bot: "botfleet-devcloudflare", label: "bot:devops" },
  security: { bot: "botfleet-audit", label: "bot:audit" },
  design: { bot: "botfleet-design", label: "bot:design" },
  knowledge: { bot: "botfleet-knowledge", label: "bot:knowledge" },
  ambiguous: { bot: "botfleet-dispatch", label: "bot:dispatch" },
};

// Keywords used for simple domain classification before LLM escalation
const DOMAIN_KEYWORDS = {
  architecture: ["archimate", "viewpoint", "enterprise architecture", "ea ", "bpmn", "archi"],
  code: ["bug", "feature", "implement", "refactor", "test", "typescript", "python", "api"],
  infrastructure: ["proxmox", "vm ", "deploy", "cloudflare", "dns", "systemd", "network"],
  security: ["audit", "security", "compliance", "vulnerability", "secret", "credential"],
  design: ["design", "ux", "ui", "branding", "mockup", "figma"],
  knowledge: ["documentation", "vault", "obsidian", "wiki", "knowledge base", "kb"],
};

/**
 * Classify an issue by domain using keyword matching.
 * Falls back to "ambiguous" if no clear match — the LLM agent
 * can refine classification for ambiguous issues.
 */
function classifyIssue(title, body) {
  const text = `${title} ${body}`.toLowerCase();
  const scores = {};

  for (const [domain, keywords] of Object.entries(DOMAIN_KEYWORDS)) {
    scores[domain] = keywords.filter((kw) => text.includes(kw)).length;
  }

  const topDomain = Object.entries(scores)
    .filter(([, score]) => score > 0)
    .sort((a, b) => b[1] - a[1])[0];

  return topDomain ? topDomain[0] : "ambiguous";
}

/**
 * Run a gh CLI command and return parsed JSON output.
 */
async function gh(args, { exec }) {
  const { stdout } = await exec("gh", args);
  return stdout ? JSON.parse(stdout) : [];
}

/**
 * Main skill entry point — called by OpenClaw cron.
 */
export default async function run({ exec, log }) {
  const result = { triaged: 0, assigned: 0, errors: [] };

  for (const org of ORGS) {
    try {
      // Fetch unassigned open issues across all repos in the org
      const unassigned = await gh(
        [
          "search", "issues",
          "--owner", org,
          "--state", "open",
          "--no-assignee",
          "--json", "number,title,body,repository,labels",
          "--limit", "20",
        ],
        { exec }
      );

      for (const issue of unassigned) {
        const repo = issue.repository?.nameWithOwner || `${org}/${issue.repository?.name}`;
        const domain = classifyIssue(issue.title, issue.body || "");
        const mapping = DOMAIN_MAP[domain];

        // Assign to target bot
        try {
          await exec("gh", [
            "issue", "edit", String(issue.number),
            "--repo", repo,
            "--add-assignee", mapping.bot,
            "--add-label", mapping.label,
          ]);

          // Add triage comment
          const comment = `📋 **dispatch-bot**: Triaged as **${domain}** → assigned to @${mapping.bot}`;
          await exec("gh", [
            "issue", "comment", String(issue.number),
            "--repo", repo,
            "--body", comment,
          ]);

          result.assigned++;
          result.triaged++;
          log(`Assigned ${repo}#${issue.number} → ${mapping.bot} (${domain})`);
        } catch (err) {
          result.errors.push(`Failed to assign ${repo}#${issue.number}: ${err.message}`);
          log(`Error assigning ${repo}#${issue.number}: ${err.message}`, "error");
        }
      }
    } catch (err) {
      result.errors.push(`Failed to query ${org}: ${err.message}`);
      log(`Error querying ${org}: ${err.message}`, "error");
    }
  }

  return result;
}
