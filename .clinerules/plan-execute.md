# Plan → Execute → Resume

Multi-phase tasks get a plan that lives on disk and survives crashes: `<project root>/.tmp-agent-scratch/` holding a `MASTER-PLAN.md` plus `phase-NNNN.md` files. The full procedure — templates, execution loop, resume, abandon — lives in the **plan-execute** skill. This rule only says when to load it.

**Resume check — at the start of EVERY task, even trivial ones, before planning anything:** if `<project root>/.tmp-agent-scratch/MASTER-PLAN.md` exists and its `Plan status:` line is not `done`, an unfinished plan exists. Load the plan-execute skill NOW and follow its Resume section before anything else. Never delete or overwrite that folder on your own initiative.

**New-task check — load the skill when ANY of these is true:**

- The task needs 2 or more distinct phases of work, or roughly 5 or more sub-tasks.
- The task will likely span more than one session, or the user may interrupt it.
- The user says "plan", "master plan", "resume", or names the scratch folder.

Below that size, skip it and plan in your reply as usual. When unsure, load it — a small plan costs little; a lost big task costs everything.

**While a plan is executing:**

- The skill text lives in the conversation, so a context compaction can erase it. After ANY compaction or session restart mid-plan: re-load the plan-execute skill, then re-read MASTER-PLAN.md and the active phase file before continuing. The plan files on disk always win over your memory of them.
- Only the main session writes plan files. **If you are a read-only subagent:** ignore all of this — do not check for, read, or resume any plan; just perform your assigned research and return your findings.
- This workflow expects Cline's **Strict Plan Mode** setting OFF: plan files are written during planning, even in PLAN MODE.
