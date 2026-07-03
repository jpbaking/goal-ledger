# PLAN → EXECUTE → RESUME — persistent task plans

This rule gives multi-phase tasks a plan that lives on disk, executes autonomously, and survives crashes. The plan is a folder of markdown files with mechanical status markers; any new session can read them and continue exactly where the last one stopped.

This rule is self-contained, and composes with the other rule files when they are present: if `00-core-reasoning-rules.md` is active, your `<steps>` block just points at the master plan file (do not duplicate the plan in chat); if `01-dox-framework.md` is active, every file edit during execution still goes through the DOX Gate.

## 0. When this rule applies

First, ALWAYS check for an unfinished plan (section 5) — that check runs at the start of every task, even trivial ones.

Then use this rule when ANY of these is true:

- The task needs 2 or more distinct phases of work.
- The task has roughly 5 or more sub-tasks.
- The task will likely span more than one session, or the user may interrupt it.
- The user says "plan", "master plan", "resume", or names the scratch folder.

Below that size, skip this rule and plan in your reply as usual (with the `<steps>` block from `00-core-reasoning-rules.md`, if that rule is active). When unsure, use this rule — a small plan costs little; a lost big task costs everything.

## 1. The scratch folder

- **Location:** `<project root>/.tmp-agent-scratch/`. The project root is the folder the task's files belong to — the one with its own `.git` or project manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Makefile`), found by walking up from the task's files. In a multi-project workspace, never the shared workspace root — one scratch folder per project. If a task truly spans several projects, put the plan in the project owning most of the work and name the other project paths in the master plan Goal.
- **Gitignore it, mechanically, right after creating it:** if the project has a `.gitignore`, run `grep -qx '.tmp-agent-scratch/' .gitignore || echo '.tmp-agent-scratch/' >> .gitignore`. If the project is a git repo with no `.gitignore`, create one containing that line. If it is not a git repo, skip this.
- **Contents:** exactly one `MASTER-PLAN.md` plus one `phase-NNNN.md` per phase (zero-padded: `phase-0001.md`, `phase-0002.md`, ...).
- **One plan at a time.** If a previous plan exists and its Plan status is `done`, you may delete those files and start fresh. If it is NOT done, never overwrite it — go to section 5, or, if the user wants to drop it, section 7.
- Never delete the scratch folder on your own initiative — deletion happens only through the Abandon procedure (section 7), at the user's explicit request. Never list `.tmp-agent-scratch/` in any `AGENTS.md` or Child DOX Index — it is temporary and gitignored; DOX Closeout does not apply to files inside it.
- **Single writer.** Only the main agent session writes plan files. Cline subagents are read-only by design and cannot update a status — never delegate a plan edit or status flip to one. Using subagents for research inside a sub-task is fine and encouraged: the `[ongoing]` marker is already on disk before you dispatch them, and YOU record their findings in the phase Log when they return. **If you are a read-only subagent:** ignore this rule entirely — do not check for, read, resume, or report on any plan; just perform your assigned research and return your findings.

## 2. Templates and status markers — copy exactly

**Status vocabulary** — these five, nothing else, always lowercase in square brackets:

- `[todo]` — not started.
- `[ongoing]` — being worked on RIGHT NOW. At most ONE `[ongoing]` phase and ONE `[ongoing]` sub-task may exist at any moment, ever. This marker is the crash flag: a resuming session treats `[ongoing]` work as unverified.
- `[done]` — finished and its "done when" check passed.
- `[skipped]` — you decided it is not needed. MUST end with ` — reason: <why>`.
- `[needs-human]` — cannot proceed without the user (a decision, clarification, credential, or a failure you could not fix). MUST end with ` — reason: <the exact question or error for the user>`.

`MASTER-PLAN.md` template:

```markdown
# MASTER PLAN — <short task title>

## Meta
- Goal: <one sentence, from <understand>>
- Done when: <overall completion check>
- Plan status: executing
- Plan status meaning: executing | done | blocked-on-human

## Phases
- [todo] phase-0001 — <title>
- [todo] phase-0002 — <title>

## Log
- created plan with <N> phases
```

`phase-NNNN.md` template:

```markdown
# phase-NNNN — <title>

- Status: todo
- Depends on: none            <!-- or: phase-0001, phase-0003 -->
- Goal: <one line>
- Done when: <check for the whole phase>

## Sub-tasks
1. [todo] <action> — done when: <check>
2. [todo] <action> — done when: <check>

## Log
- (append one line per event; never edit or delete old lines)
```

Rules:

- A phase file's `Status:` line is the source of truth for that phase; the matching line in MASTER-PLAN.md is a mirror. Update both in the same breath. On any mismatch, the phase file wins — fix the master.
- Every phase and every sub-task MUST have a "done when" check you can actually run or observe.
- Keep it small: 2–7 phases, 2–7 sub-tasks each. Work that needs more sub-tasks becomes another phase, not a longer list.
- Statuses live at the start of the line so they can be flipped with a single targeted replace (`1. [todo] ...` → `1. [ongoing] ...`). Never rewrite a whole plan file just to change one status.
- Never renumber existing phases or sub-tasks. New work discovered mid-flight gets the next free number, plus a Log line in the master saying what was added and why.

## 3. Writing the plan

1. Before writing any plan file, state the task in one sentence, state what "done" means, and choose one approach — inside the `<understand>` and `<plan>` blocks if `00-core-reasoning-rules.md` is active, otherwise plainly in your reply. The chosen approach becomes the master plan (its Goal and "Done when" come straight from this); its decomposition becomes the phases.
2. **Write the plan files immediately — in either mode.** Creating `.tmp-agent-scratch/` and its files is part of planning itself, not part of executing: this workspace expects Cline's **Strict Plan Mode** setting to be disabled, so these writes are allowed even in PLAN MODE. Create the scratch folder, gitignore it, and write MASTER-PLAN.md and every phase file now, before any other work.
3. **Fallback — only if file writes are actually blocked** (Strict Plan Mode turned out to be enabled): compose the full MASTER-PLAN.md and every phase file inside your response, as fenced blocks. When switched to ACT MODE, your FIRST tool actions — before any other work — are: create the scratch folder, gitignore it, write those files to disk exactly as composed.
4. Show the user the phase list (one line each). If the task already said to execute, go to section 4 immediately. Otherwise ask nothing and wait — the user will say when.

## 4. Execution loop — autonomous

**Status discipline (the crash-safety core):** write `[ongoing]` to disk BEFORE starting an item, and write its terminal status (`[done]` / `[skipped]` / `[needs-human]`) to disk IMMEDIATELY after finishing it — before touching the next item, never batched, never deferred to the end.

**Focus Chain:** if Cline's Focus Chain todo list is enabled, keep it a COARSE mirror of the master plan — one focus-chain item per phase, ticked when the phase closes. Never copy sub-tasks into it. The plan files are the source of truth; if the two disagree, fix the focus chain to match the files, never the reverse.

**Permissions:** the user grants tool permissions through Cline's auto-approve settings for the session (read files, edit files, execute safe — or all — commands). Whatever those settings have checked, you are explicitly allowed to do throughout this loop — read, write, and execute across the workspace — WITHOUT asking for permission in chat. Never pause to ask "may I edit/run…?" for an action the settings already auto-approve; that stalls the autonomous loop for nothing. If an action is NOT covered, Cline itself will show the user an approval prompt — wait for their click and continue. An approval pause is the harness working as intended: it is not a failure, not an interruption of the loop, and never a reason to mark an item `needs-human`.

Loop:

1. Read MASTER-PLAN.md. Pick the first phase that is `[todo]`.
2. Check its `Depends on:` list. Every listed phase must be `[done]`. If not, leave it `[todo]`, log `deps not met` in the master Log, and try the next `[todo]` phase.
3. Mark the phase `[ongoing]` (phase file Status line AND master mirror). Log `started` in the phase Log.
4. For each sub-task in order:
   a. Flip it to `[ongoing]`. Save the file.
   b. Do the work. Any other active rules still apply here — e.g. `00`'s read-before-edit and verification discipline, `01`'s DOX chain.
   c. Run its "done when" check.
   d. Flip it to `[done]`, or `[skipped] — reason: ...`, or — after 2 failed attempts on the same sub-task — `[needs-human] — reason: <exact error/question>`. Save. Append one Log line saying what happened.
   e. A `[needs-human]` sub-task does NOT stop the loop: continue with the next sub-task if it does not depend on the failed one; otherwise close the phase now (step 5).
5. **Close the phase with a review.** When no `[todo]`/`[ongoing]` sub-tasks remain (or step 4e forced closure), do NOT mark the phase done yet:
   a. Run the phase's own "done when" check — the whole-phase one, not the sub-tasks'. Sub-tasks can all pass while the phase goal is still missed.
   b. Review against the master plan: re-read MASTER-PLAN.md's Goal and the remaining phases. Did this phase's outcome — or anything discovered while doing it — change what a later `[todo]` phase must do? If yes, amend those phase files NOW, while the details are still in context: edit `[todo]` phases freely, add new phases with the next free numbers, never touch `[done]` ones. Log what changed and why in the master Log.
   c. If the phase "done when" check fails: the phase is not done — add a fix-up sub-task (next free number) and continue at step 4. After 2 failed fix-up rounds, set the phase to `needs-human — reason: <what still fails>`.
   d. Now set the phase Status: `done` (all sub-tasks done/skipped AND the phase check passed) or `needs-human` (any sub-task needs-human, or step c gave up). Mirror it in the master, append a one-line summary to the master Log.
6. **Compact at the boundary** — context hygiene, done autonomously, no user permission needed:
   a. A phase boundary is the ideal compaction point: everything durable was just written to disk, so what the summary loses, the plan files still hold. A mid-phase auto-compaction picks the worst possible moment instead — this step is how you prevent it.
   b. Check your context window usage (shown in environment details). Below roughly half: skip this step entirely and go to step 7. At roughly half or more: compact now.
   c. Before compacting, do a **pre-compaction flush** — treat the compaction as a planned crash: anything you still need that is NOT yet in the plan files (a decision made, a gotcha found, a port, a path, a command that works) gets appended to the phase Log or master Log first. After compaction you must be able to continue from the plan files plus the summary alone.
   d. Compact using Cline's context condensing (the same summarization Auto Compact / `/smol` uses).
   e. Immediately after compacting, re-anchor exactly like a resume: re-read MASTER-PLAN.md and the next phase file before doing anything else. Wherever the summary and the plan files disagree, the files win.
   f. Never compact mid-phase or mid-sub-task by choice — boundaries only.
7. Go back to step 1. Do NOT stop between phases, do not ask "shall I continue?", do not summarize progress mid-run. Stop ONLY when one of these is true:
   - **All phases are terminal, none needs-human** → set Plan status to `done`. Report.
   - **Nothing actionable remains** (every remaining phase is `[needs-human]` or is `[todo]` with unmet dependencies) → set Plan status to `blocked-on-human`. Report.
   - **The user interrupts** → the files already hold the exact state; nothing extra to do.

## 5. Resume — new session or after a crash

At the start of EVERY task, before planning anything: check whether `<project root>/.tmp-agent-scratch/MASTER-PLAN.md` exists with Plan status not `done`.

- If the user asked to continue/resume, or the new request matches the plan's Goal: resume without asking.
- If the plan is `blocked-on-human` and the user's message answers its questions: record the answers in the affected items' Log, flip those items back to `[todo]`, set Plan status to `executing`, resume.
- If the new request is unrelated: tell the user an unfinished plan exists (quote its Goal and progress counts) and ask — resume it, set it aside and do the new task, or abandon it (section 7). Never silently delete it.

Resume procedure:

1. Read MASTER-PLAN.md fully.
2. Find any `[ongoing]` phase; read its file; find any `[ongoing]` sub-task.
3. **Trust nothing marked `[ongoing]`** — it may have died mid-write. Run that sub-task's "done when" check and read its Log:
   - Check passes → flip to `[done]`, log `verified on resume`.
   - Check fails or is half-done → redo the sub-task from its start (flip stays `[ongoing]` while you do).
4. Fix any invariant violations you find (two `[ongoing]` items, master/phase status mismatch — phase file wins) before doing anything else.
5. Append `resumed` to the master Log and re-enter the loop at section 4 step 1.

## 6. Reporting on stop

Whenever the loop stops (done or blocked), report in this shape and nothing more:

```
Plan: <title> — <done | blocked-on-human>
Phases: <X> done, <Y> skipped, <Z> needs-human, <W> todo (blocked)
Needs you:
- phase-NNNN sub-task N: <the exact question / error>   <- one line per needs-human item; omit section if none
```

## 7. Abandon — reset / clean up the plan

Run this ONLY when the user explicitly asks to abandon, reset, scrap, or clean up the current plan — or picks "abandon" when offered in section 5. Never run it on your own judgment, and never as a shortcut around a blocked or messy plan.

1. Read MASTER-PLAN.md. Show the user exactly what they are abandoning: quote the Goal and the progress counts (X done, Y skipped, Z needs-human, W todo), and list any pending needs-human questions — those will be lost too.
2. Warn them, stating both of these facts plainly:
   - **There is no rollback.** The master plan, every phase file, their logs, and all pending questions are permanently deleted. A resumed or new session cannot recover any of it.
   - **This does not undo work.** Changes already made to the project files stay exactly as they are — only the plan and its bookkeeping are deleted. If they want the work itself reverted, that is a separate task (e.g. via git), not this procedure.
3. Ask for explicit confirmation. The default is NO: anything other than a clear yes means keep everything and stop here.
4. On yes: delete the entire `.tmp-agent-scratch/` folder. Confirm to the user that the plan is gone and that no project files were touched.
5. On no: change nothing, say so in one line, and continue with whatever the user wants next.
