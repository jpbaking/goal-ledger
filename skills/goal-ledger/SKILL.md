---
name: goal-ledger
description: >-
  Create and execute a durable, git-tracked Goal Ledger for multi-phase or
  long-running work: .goal-ledger/GOAL.md plus phase-NNNN.md files, plan and
  execution approval gates, an isolated goal branch recommendation, committed
  recovery markers, inter-agent handoff state, and optional safe squashing on
  acceptance. Use when work needs several distinct phases, may span sessions,
  needs crash recovery or handoff, or the user asks for a persistent goal,
  execution ledger, or durable plan. Sections 1-3 are the shared contract used
  by the goal-ledger-resume, goal-ledger-status, and goal-ledger-abandon skills.
---

# Goal Ledger — prepare and execute a durable goal

Goal Ledger is a git-tracked execution record for one goal. It survives crashes, context compaction, session changes, and handoff to another agent. The files and Git state are authoritative; memory and conversation summaries are not.

Sections 1–3 are the shared contract used by every Goal Ledger skill.

## 1. Ledger location and lifecycle

- **Location:** `<project root>/.goal-ledger/`. The project root owns the task's files and has its own repository or project manifest; never place the ledger at a multi-project workspace root.
- **Tracked state:** never add `.goal-ledger/` to `.gitignore`. Verify with `git check-ignore -v .goal-ledger/GOAL.md`. Remove an exact Goal Ledger ignore entry; if a broader user-owned pattern is responsible, explain it and obtain approval before adding a narrow negation or changing that pattern.
- **Contents:** exactly one `GOAL.md` plus one `phase-NNNN.md` per phase. Keep phase files beside `GOAL.md`; another directory level adds no useful information.
- **One current ledger:** never overwrite a goal whose status is not `completed` or `abandoned`. Resume it or use `goal-ledger-abandon`.
- **Completed history:** keep the completed ledger in the final committed snapshot. A later goal may replace `.goal-ledger/` only after its own plan is approved; the previous ledger remains recoverable from Git history.
- **Single writer:** only the primary session updates ledger files. Subagents may perform bounded phase work, but the primary session records their findings and changes statuses.
- **Delegation boundary:** every subagent prompt must say: `Ignore .goal-ledger and all Goal Ledger skills. Follow only the task in this prompt; do not create, resume, update, or abandon the ledger.` Include all task-local context the subagent needs. Do not delegate ledger bookkeeping, branch management, or framework commits. If you are a subagent, ignore the ledger and continue only the assigned prompt; an unfinished ledger is not a blocker for that delegated task.

## 2. File format and invariants

Use a stable Goal ID: `YYYYMMDD-<short-kebab-slug>`. If that ID already appears in repository history, append `-2`, `-3`, and so on. The recommended branch is `goal/<goal-id>`.

The `GOAL.md` mirror and sub-task vocabulary is exactly: `[todo]`, `[ongoing]`, `[done]`, `[skipped] — reason: <why>`, and `[needs-human] — reason: <question/error>`. A phase file uses the same value without brackets on its `Status:` line. At most one phase and one sub-task may be ongoing.

`GOAL.md`:

```markdown
# GOAL — <short title>

## Goal
- Goal ID: <stable ID>
- Outcome: <one sentence>
- Done when: <observable completion check>
- Goal status: drafting
- Goal status meaning: drafting | approved | executing | blocked-on-human | awaiting-acceptance | completed | abandoned
- Last completed phase: none

## Git
- Repository: yes | no
- Strategy: isolated-branch | current-branch | none
- Starting branch: <branch | "-">
- Work branch: <branch | "-">
- Baseline commit: <full immutable SHA | "-">
- Starting upstream at start: <ref>@<full SHA> | none | "-"
- Work upstream at start: <ref>@<full SHA> | none | "-"

## Phases
- [todo] phase-0001 — <title>

## Handoff
- Current position: planning
- Next action: approve the goal
- Last verified evidence: none
- Blockers: none

## Log
- created ledger with <N> phases
```

`phase-NNNN.md`:

```markdown
# phase-NNNN — <title>

- Status: todo
- Depends on: none
- Goal: <one line>
- Done when: <runnable or observable check>

## Sub-tasks
1. [todo] <action> — done when: <check>

## Log
- (append-only, one line per event)
```

Invariants:

- The phase file's `Status:` is authoritative; the matching bracketed line in `GOAL.md` mirrors it. Repair mismatches in favor of the phase file.
- Every phase and sub-task has an observable "done when" check.
- Use 2–7 phases with 2–7 sub-tasks each. Add new numbered phases or sub-tasks; never renumber existing ones.
- Update `Handoff` whenever execution changes position, evidence, next action, or blockers. It must let a new agent continue without the conversation.
- Append important events and decisions to logs. Never rewrite history to make a failed attempt disappear.
- Do not store a moving `HEAD` hash in `GOAL.md`. The immutable baseline and Git history are authoritative; a commit cannot reliably record its own hash.
- During drafting, set only `Repository`; use `Strategy: none` and `-` for every other Git field. Gate B replaces those placeholders from live Git state immediately before the first ledger commit.

## 3. Git contract

If `Repository: no`, use `Strategy: none`, keep Git fields as `-`, skip every Git operation, and never initialize a repository automatically.

For a repository:

- **Clean start:** before preparing Git, classify `git status --porcelain`. Changes inside `.goal-ledger/` are expected planning state. Any other pre-existing change must be resolved by the user: commit it, explicitly authorize a baseline snapshot commit, stash it, or stop. Never absorb unrelated work into the goal.
- **Immutable baseline:** record the full `HEAD` before the first Goal Ledger commit. Every goal commit lives strictly after this baseline.
- **Recommended isolated branch:** recommend `goal/<goal-id>`. Ask before creating or switching branches. Record the original branch as `Starting branch` and the goal branch as `Work branch`. From a detached `HEAD`, require creation of a named goal branch or stop for user direction; `current-branch` is not valid without a branch.
- **Current-branch fallback:** if the user declines a goal branch, warn that shared or interleaved history can make automatic squashing unavailable. Record both branch fields as the current branch and use `Strategy: current-branch`.
- **Upstream snapshots:** before switching, record the starting branch's upstream ref and full SHA without fetching, or `none`. After choosing the work branch, record its upstream the same way. For `current-branch`, the two snapshots are identical; for a new isolated branch, the work upstream is normally `none`.
- **Commit identity:** every framework-created commit after the baseline has a `Goal-ID: <goal-id>` trailer. Phase commits also have `Goal-Phase: phase-NNNN`. Git history, not hashes copied into the ledger, is the commit ledger.
- **Committed recovery marker:** before doing phase work, set the phase file to `Status: ongoing`, set its `GOAL.md` mirror to `[ongoing]`, update Handoff, and commit the ledger as `goal-ledger(begin): phase-NNNN — <title>`. A clean tree after that commit means no work started; later dirty files identify interrupted work.
- **Phase close:** update the phase, mirror, `Last completed phase`, Handoff, and logs; inspect the worktree; stage only goal-owned changes; then commit as `goal-ledger(done): phase-NNNN — <title>` or `goal-ledger(blocked): phase-NNNN — <title>`.
- **Never automatically:** push, force-push, delete a branch, amend, rebase, hard-reset, or touch commits at or before the baseline.

### Optional squash on acceptance

Offer squashing only after the user accepts the finished result. Before offering, require all of these:

1. The worktree is clean.
2. The current branch equals `Work branch`.
3. Every commit in `<baseline>..HEAD` carries the matching Goal ID.
4. The range has no merge commit or foreign/interleaved commit.
5. No goal commit is reachable from either recorded upstream or any locally known remote-tracking ref. If the goal branch was published for handoff, keep its commits and recommend a squash merge at integration time instead of rewriting the branch. If publication is uncertain, do not automate the squash.
6. For `current-branch`, its upstream ref still points to the SHA recorded at Gate B. If that ref advanced, rewound, or diverged, do not automate the squash even when the local goal range itself contains no foreign commit.

If any check fails, keep the commits and explain why. If all pass and the user explicitly chooses squash: soft-reset to the baseline, set the goal status to `completed`, update Handoff to completed with no next action, append the acceptance/squash event, retain the entire `.goal-ledger/`, stage the accepted snapshot, and create one meaningful commit with the Goal ID trailer. If the user declines squash: make the same terminal ledger updates and create a final `goal-ledger(complete): <title>` commit. The completed ledger must remain in either result.

## 4. Draft the ledger

1. Inspect the project and establish the outcome, overall "done when", approach, phases, dependencies, and checks.
2. Inspect Git state before writing so pre-existing changes can be distinguished from ledger files later.
3. If no ledger exists, create `.goal-ledger/GOAL.md` with status `drafting` and every phase file. Do not change application code.
4. If an older ledger is `completed` or `abandoned`, preserve it until the new plan is approved. Draft the proposed replacement in the conversation or a temporary location outside the project, then write it into `.goal-ledger/` only after Gate A. The new goal's first commit records the replacement, leaving the previous ledger in Git history.

## 5. Approval and Git preparation gates

**Gate A — approve the goal:** show Outcome, Done when, and the one-line phase list. Ask for approval. Apply feedback to the ledger and repeat until approved, then set status `approved` and update Handoff.

**Gate B — choose and prepare the Git strategy:** resolve non-ledger dirty changes first and verify the ledger is not ignored. Strongly recommend the isolated goal branch and explain that it makes recovery, handoff, abandonment, and optional squashing deterministic. Ask permission to create/switch to it. If declined, show the current-branch warning and obtain explicit confirmation. Record all Git metadata, then commit the approved ledger as `goal-ledger(approve): <title>` with the Goal ID trailer.

**Gate C — execute:** ask whether to start execution. On yes, enter the loop. A single clear response such as "approved, create the branch, and go" may satisfy all gates. The original task request never pre-approves an unseen ledger or a branch change.

## 6. Execution loop

1. Select the first `[todo]` phase whose dependencies are all `[done]`.
2. Set Goal status `executing`; set the phase file to `Status: ongoing` and its `GOAL.md` mirror to `[ongoing]`; update Handoff and logs; create the committed recovery marker from section 3.
3. For each sub-task: mark `[ongoing]` before work; perform it; run its check; immediately mark `[done]`, `[skipped] — reason:`, or after two failed attempts `[needs-human] — reason:`; update the phase Log and Handoff.
4. Run the phase-level check. If it fails, add a fix-up sub-task. After two failed fix-up rounds, mark the phase `needs-human`.
5. Review the overall Goal and remaining phases. Amend only future `[todo]` phases, logging why.
6. Close and commit the phase under section 3. If nothing actionable remains, include Goal status `blocked-on-human` in that close commit (or create a blocked-state commit if no phase was closed), then stop.
7. At a phase boundary, compact context if useful, then re-anchor from `GOAL.md`, the next phase file, and Git. After uncertain or interrupted state, use `goal-ledger-resume`.
8. Continue without asking between phases. When every phase is terminal and none needs human, set Goal status `awaiting-acceptance`, update Handoff, include that state in the final phase commit, report, and ask the user to review the result.
9. After acceptance, apply the optional squash procedure or create the completion commit. Do not delete the ledger.

## 7. Report when execution stops

```text
Goal: <title> — <awaiting-acceptance | blocked-on-human>
Goal ID: <id>
Strategy: <isolated-branch | current-branch | none> on <work branch>
Phases: <X> done, <Y> skipped, <Z> needs-human, <W> todo
Commits: <N> matching goal commits since <baseline>   (omit without Git)
Needs you:
- phase-NNNN sub-task N: <exact question or error>    (omit if none)
```
