@AGENTS.md

## Claude Code specifics

The main session is the orchestrator. It plans each milestone, writes the task specs, sends work to the agents in `.claude/agents/`, merges their results and keeps `PLAN.md` current. When a step needs a decision only the owner can make, add it to "Waiting on the owner" in `PLAN.md` and continue with other work.

**Pick the agent by the work, not by habit.** Each agent's model is set in its frontmatter:

| Work | Agent | Model |
|---|---|---|
| Find code in the repo | `Explore` | Haiku |
| Look up a library, price or provider fact | `researcher` | Sonnet |
| Schemas, OpenAPI, validator, codegen | `contract-engineer` | Sonnet |
| Worker, D1, GitHub App, caching | `edge-backend-engineer` | Sonnet |
| Flutter screens, viewers, litse-ui components | `frontend-engineer` | Sonnet |
| Visual review from screenshots | `design-reviewer` | Opus |
| Security review | `security-reviewer` | Opus |
| Tests and the traceability matrix | `qa-engineer` | Sonnet |
| ADRs, runbooks, compliance docs | `docs-pm` | Sonnet |
| Interface copy | `copywriter` | Sonnet |

Do small, sequential or single-file work directly instead of delegating. Code-writing agents run in a git worktree; merge their branch only after its Verify command passes.

**Second model: Codex as a working partner.** The owner asked (2026-11-22) for Codex to be involved more, though not for it to take over: Claude's agents stay the main builders. Share the work like this:

- **Claude's agents** do most of the implementation (the app, the Worker, contracts and tests), and Claude orchestrates, reviews and merges.
- **Codex makes images**: logos, illustrations, covers, visual concepts and art direction, using its image generation tool. It pairs with the design lead on visual work.
- **Codex critiques**: a second opinion on screenshots, screen specs and copy, and a required review of every security-sensitive diff and milestone plan (mode 1).
- **Codex implements some isolated, well-specified tasks** in its own worktree (mode 2): about one in three, picked where its strengths fit (the static site, scripts, a proof of concept) or when Claude usage runs low. Claude reviews its diff, runs the Verify commands itself, and merges.

Use the `codex-dispatch` skill. Run `codex login status` first; if it is logged out, ask the owner to complete `codex login --device-auth`. Run long Codex jobs in the background and keep working.

**Research.** Get facts from pages fetched during the task, never from memory. The WebFetch tool can't reach some documentation hosts from the cloud sandbox, so use `curl -sL <url> | pandoc -f html -t plain`. developers.cloudflare.com serves Markdown at `<page>/index.md`. Save findings to `docs/research/` so nobody looks them up twice.

**Output.** Bash output passes through RTK. For the full output of a failing command, run `rtk recall <hash>` or `rtk bypass <command>`.
