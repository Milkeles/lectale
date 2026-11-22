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

**Second model: Codex takes the volume.** Claude usage runs out much faster than the owner's ChatGPT plan, and the owner asked (2026-11-22) for Codex to carry more of the work. So, by default:

- **Codex implements** every well-specified task: a renderer, a screen from an approved spec, the static site, a workflow, a proof-of-concept script. It runs in its own git worktree (`codex-dispatch`, mode 2), from a task spec in `spec/tasks/` with the intake gate and exact Verify commands.
- **Codex critiques**: screenshots, screen specs, copy, and every security-sensitive diff and milestone plan (mode 1). Design and copy critiques go to Codex first; the Opus `design-reviewer` is kept for a final pass before the owner sees a screen.
- **Codex makes images**: logos, illustrations, covers and visual concepts.
- **Claude orchestrates and judges**: plans, writes the task specs, reviews Codex's diff, runs the Verify commands itself, does security reviews of trust-boundary code, and merges. Claude agents take work that needs this conversation's context or a skill Codex lacks.

Use the `codex-dispatch` skill. Run `codex login status` first; if it is logged out, ask the owner to complete `codex login --device-auth`. Run long Codex jobs in the background and keep working.

**Research.** Get facts from pages fetched during the task, never from memory. The WebFetch tool can't reach some documentation hosts from the cloud sandbox, so use `curl -sL <url> | pandoc -f html -t plain`. developers.cloudflare.com serves Markdown at `<page>/index.md`. Save findings to `docs/research/` so nobody looks them up twice.

**Output.** Bash output passes through RTK. For the full output of a failing command, run `rtk recall <hash>` or `rtk bypass <command>`.
