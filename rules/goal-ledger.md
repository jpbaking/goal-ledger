# Goal Ledger family

Goal Ledger is a git-tracked execution record for one goal, designed for crash recovery and inter-agent handoff. Its state lives in `<project root>/.goal-ledger/`: `GOAL.md` plus `phase-NNNN.md` files. Procedures live in four skills; load exactly one:

| Situation | Load |
|---|---|
| New multi-phase or long-running goal | **goal-ledger** — draft, approve, prepare Git, execute |
| Unfinished ledger / "resume" / "continue" / recovery after a crash or compaction | **goal-ledger-resume** — verify, reconcile, continue |
| "where are we" / "goal status" / "what is left" | **goal-ledger-status** — read-only report |
| Explicit "abandon" / "cancel" / "scrap this goal" | **goal-ledger-abandon** — preserve the record and mark it abandoned |

**Resume check:** at the start of every primary-session task, if `.goal-ledger/GOAL.md` exists with a `Goal status:` other than `completed` or `abandoned`, load `goal-ledger-resume` before starting unrelated work. Never overwrite or delete an unfinished ledger. This check does not apply to a subagent working from a delegated prompt.

**When to start:** use Goal Ledger when work needs several distinct phases, may outlive one session, needs a durable agent handoff, or the user asks for a persistent goal or execution ledger. Ordinary short planning is not a trigger.

**Git strategy:** strongly recommend an isolated `goal/<goal-id>` branch. If the user stays on the current branch, preserve the same baseline and Goal-ID tracking but apply stricter squash checks. Never rewrite shared or published history automatically.

**Continuity:** ledger files and Git win over memory and conversation summaries. Only the primary session writes ledger files. Whenever it delegates work, the primary must tell the subagent explicitly: `Ignore .goal-ledger and all Goal Ledger skills. Follow only the task in this prompt; do not create, resume, update, or abandon the ledger.` The primary supplies the task-local context and records the returned evidence in the ledger.
