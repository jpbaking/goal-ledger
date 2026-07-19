# Goal Ledger — agent-guided install

You are an AI coding agent installing Goal Ledger into the project at the
current working directory. Follow these steps exactly. This procedure is
merge-aware: it never blindly overwrites files the project already owns, which
is why it is preferred over the script installers.

Source repository: `https://github.com/jpbaking/goal-ledger` (raw base:
`https://raw.githubusercontent.com/jpbaking/goal-ledger/main`). If the user
named a fork or tag, substitute it in every URL below.

## 1. Survey before writing

1. Confirm you are at the target project's root.
2. If `.tmp-agent-scratch/MASTER-PLAN.md` exists with a plan status other than
   `done`, STOP and report it — an unfinished legacy plan must be resumed,
   finished, abandoned, or migrated before installing.
3. Ask (or infer from the user's request) which harnesses to support:
   Codex/Antigravity (`.agents` + `AGENTS.md`), Claude Code (`.claude`),
   Gemini CLI (`GEMINI.md` + `.agents`), Cline (`AGENTS.md` + `.agents`).
   Default: all.
4. Check for same-named `goal-ledger*` or legacy `master-plan*` artifacts
   under `.agents/`, `.claude/`, `.cline/`, `.clinerules/`,
   `.claude/commands/`, and the user-global skill directories. Report
   collisions; never delete unrelated or legacy files.

## 2. Install the skills

For each skill `goal-ledger`, `goal-ledger-resume`, `goal-ledger-status`,
`goal-ledger-abandon`, fetch the full directory from
`skills/shared/<skill>/` (at minimum `SKILL.md`; `goal-ledger` also bundles
`scripts/validate_goal_ledger.py`) and write byte-identical copies to:

- `.agents/skills/<skill>/` — when Codex/Antigravity, Gemini, or Cline are
  selected;
- `.claude/skills/<skill>/` — when Claude Code is selected.

Replace whole same-named skill directories so retired bundled resources
cannot linger. Verify each skill's frontmatter `name` matches its directory.

## 3. Install the rule

Fetch `rules/shared/goal-ledger.md` and write it to `.agents/rules/` (shared
harnesses) and `.claude/rules/` (Claude Code). Never write to `.codex/rules`.

## 4. Bridge files — merge, never overwrite

For `AGENTS.md` (Codex/Antigravity/Cline) and `GEMINI.md` (Gemini CLI): if
the file already mentions `.agents/rules/goal-ledger.md`, leave it. Otherwise
create it if missing (`# Project rules` / `# Project context` heading) and
append this section once, preserving existing content:

> ## Goal Ledger
>
> If `.agents/rules/goal-ledger.md` exists, read and follow it. Reusable
> procedures live in `.agents/skills/`; use the matching skill when its
> description applies. If the rule or skills are missing (fresh clone — the
> installed adapters are gitignored), re-run the Goal Ledger installer from
> https://github.com/jpbaking/goal-ledger to regenerate them.

Claude Code needs no `CLAUDE.md` bridge — it auto-discovers `.claude/rules/`.
If `CLAUDE.md` already imports `@.claude/rules/goal-ledger.md`, warn that the
import is redundant (and would dangle on a fresh clone); preserve the line.

## 5. Gitignore the generated adapters

Add this block to the project's `.gitignore` once (skip if the marker exists);
never delete existing rules:

```gitignore
# Goal Ledger installer-managed agent adapters (generated; do not edit or commit)
.agents/skills/goal-ledger/
.claude/skills/goal-ledger/
.agents/skills/goal-ledger-resume/
.claude/skills/goal-ledger-resume/
.agents/skills/goal-ledger-status/
.claude/skills/goal-ledger-status/
.agents/skills/goal-ledger-abandon/
.claude/skills/goal-ledger-abandon/
.agents/rules/goal-ledger.md
.claude/rules/goal-ledger.md
```

Do NOT gitignore `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, or — critically —
the runtime `.goal-ledger/` directory: the ledger itself is a committed,
git-tracked execution record. Only the installed rule/skill adapters are
generated files. A fresh clone therefore lacks the adapters; the conditional
bridge text degrades safely, and re-running this procedure (or `install.sh`)
regenerates them.

## 6. Validate and report

1. When both `.agents` and `.claude` copies exist, verify each skill
   directory pair is byte-identical.
2. Verify every selected harness reaches the rule through exactly one path.
3. Report every file created, changed, or intentionally left alone, plus
   collisions and warnings from step 1.
4. Tell the user: ask their agent to use the `goal-ledger` skill for
   multi-phase work (`goal-ledger-resume` for recovery/handoff,
   `goal-ledger-status` for a read-only report, `goal-ledger-abandon` to stop
   while preserving history).
