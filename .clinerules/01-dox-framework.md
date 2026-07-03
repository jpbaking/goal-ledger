# DOX framework compliance

This rule makes you follow the DOX framework (https://github.com/jpbaking/dox) — a tree of `AGENTS.md` files that give local, per-folder context — for any project in this workspace that has adopted it. It works for both workspace shapes: a workspace that IS a single project, and a workspace folder holding several sibling projects (possibly unrelated), each with its own independent `AGENTS.md` tree or none at all. Never hardcode a project name: every decision below is made per target, from what is on disk.

If `00-core-reasoning-rules.md` is active, run the Gate as part of your `<understand>` block.

## Gate — run before you edit or create any file

Reading and exploring to find your targets is allowed before the Gate. Editing or creating files is not.

1. List the file(s) and folder(s) you are about to change.
2. For each one, collect its **candidate docs**: start in the target's own folder and walk up one folder at a time until you reach the workspace root (inclusive). Note EVERY folder on that path that contains an `AGENTS.md` file.
3. **No candidates on the whole path:** go to section A for that target.
4. **Candidates exist — find the project root:** apply the DOX test (below) to each candidate's `AGENTS.md`, starting from the TOPMOST candidate (the one closest to the workspace root) and moving downward. The FIRST candidate that passes is that target's **project root**. Do NOT assume the `AGENTS.md` nearest the target is the project root — lower docs (for example `backend/AGENTS.md` inside a project) are child docs or sub-roots, and a non-DOX `AGENTS.md` sitting at the shared workspace root of a multi-project workspace is not a project root either; the top-down test skips both correctly.
   - **A candidate passes cleanly:** project root found — go to section B.
   - **A candidate passes only by fallback** (first line is not `# DOX framework`, but the three headers are present): project root found, but it has drifted — do section C first, then section B.
   - **No candidate passes:** DOX does not apply to that target. Say nothing about DOX — no recommendation, no restructuring. Follow the nearest `AGENTS.md` as-is.
5. If targets resolve to different project roots (or some to none), handle each project separately. A verdict for one project never applies to another.

**DOX test** — passes only if both are true:

- The first line is exactly `# DOX framework`. (Fallback: the title was changed, but the doc still contains all three headers `## Child DOX Index`, `## Feature Map`, and `## Read Before Editing`.)
- The doc contains the phrase "hierarchy of AGENTS.md files".

**Framework sections** — canonical list, referenced by sections A, B, and C. A healthy project-root `AGENTS.md` is the upstream framework doc **verbatim**: the title `# DOX framework`, then `## Core Contract`, `## Hierarchy`, `## Where a doc goes: boundaries`, `## Child Doc Shape`, `## Feature Map`, `## Initialization`, `## Read Before Editing`, `## Update After Editing`, `## Style`, `## Closeout`, `## User Preferences`, `## Child DOX Index` — in that order. Project-specific content lives in exactly three places: the `## User Preferences` body, the `## Child DOX Index` entries, and the project's own feature bullets appended at the END of `## Feature Map` (below the rules text already in that section). A project root NEVER has `Purpose`, `Ownership`, `Local Contracts`, `Work Guidance`, or `Verification` sections — those belong only to child and sub-root docs (see Child Doc Shape).

## A. No AGENTS.md yet

First decide which folder DOX would live in, mechanically:

- **The workspace root itself is a project** (it directly contains a `.git` folder or a project manifest like `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Makefile`): the candidate folder is the workspace root.
- **The workspace root is a container of projects** (no manifest of its own; its top-level folders are the projects): the candidate folder is the target's top-level folder under the workspace root. If the target sits directly in the workspace root (a loose file in a container workspace), skip DOX for it entirely.
- **Unclear which shape applies:** ask the user which folder is the project root before recommending anything.

Then tell the user briefly: the project at `<candidate folder>` has no `AGENTS.md`, and recommend setting up DOX there — a lightweight tree of `AGENTS.md` docs that gives precise per-folder context instead of guessing from the whole codebase. Ask if they want it set up now. Do not create any file yet. If they decline, proceed normally and do not ask again this session.

If the user says yes:

1. **Install the framework doc by downloading it — never by retyping it.** In the candidate folder chosen above, run via execute_command:
   `curl -sSL https://raw.githubusercontent.com/jpbaking/dox/main/AGENTS.md -o AGENTS.md`
   If curl is unavailable, fetch that URL with your web-fetch tool and write the fetched text verbatim with write_to_file. If you cannot fetch it at all: tell the user and stop — NEVER write the framework doc from memory.
2. **Verify the download mechanically.** `head -1 AGENTS.md` must print `# DOX framework`, and `grep '^## ' AGENTS.md` must list every one of the Framework sections above. If anything is missing or different, delete the file and re-download. Do not patch it from memory.
3. **Fetch the current README** from `https://raw.githubusercontent.com/jpbaking/dox/main/README.md` — live, not from memory. This rule intentionally embeds none of its prompts so they can never go stale.
4. From that README, take the **long-form** prompt (not the "Short form" collapsible): "New project" if the project has little or no code yet, "Existing project" if it already has code. Point it at the candidate folder as the project root, and keep everything it creates inside that folder — in a container workspace, never let it index or write into sibling projects.
5. Follow that prompt exactly, step by step, skipping nothing. It fills in the `## Child DOX Index`, the project's feature bullets, and the child/sub-root docs. It must not alter the framework text installed in step 1 — the root-doc editing rule in section B step 6 applies from now on.
6. Re-run the Gate for that project; it will now route you to section B.

## B. DOX is active

For the rest of the task, for every target under that project root:

1. Read the project root's `AGENTS.md` in this session — not from memory.
2. State which files or folders you plan to touch within the project.
3. For each one, read every `AGENTS.md` on the path from the project root DOWN to the target, including any sub-root on the way. Re-read them now even if you read them earlier in the session.
4. The nearest `AGENTS.md` is the local contract; every `AGENTS.md` above it, up to the project root and no further, gives that project's repo-wide rules. Never read or apply docs above the project root — in a multi-project workspace those belong to other projects or to nobody. On conflict, the closer doc wins on local detail — but no child or sub-root may weaken DOX itself.
5. Do the work, following those docs.
6. **Closeout** (skip if the task changed no files): update the nearest owning `AGENTS.md` for anything you changed, refresh every affected `Child DOX Index` and `Feature Map`, and tell the user what you updated — or that you checked and nothing needed updating.

   **Root-doc editing rule:** in the project root's `AGENTS.md` you may ONLY (a) edit the `## User Preferences` body, (b) edit the `## Child DOX Index` entries, (c) add/adjust the project's own feature bullets at the end of `## Feature Map`. Never shorten, reword, reorder, merge, or delete the framework text, never rename the `# DOX framework` title, and never add `Purpose`, `Ownership`, `Local Contracts`, `Work Guidance`, or `Verification` sections to it — those exist only in child and sub-root docs. If you find the root doc already violating this, go to section C.

## C. Repair a drifted project-root doc

Use this when the Gate's DOX test passed only by fallback, or the project root's `AGENTS.md` is missing or has altered Framework sections.

1. Tell the user the project root doc has drifted from the DOX framework and list exactly what is missing, renamed, or added.
2. Save aside the current content of `## User Preferences`, the `## Child DOX Index` entries, and any project feature bullets in `## Feature Map`.
3. If the drifted doc contains OTHER project-specific sections (for example `Purpose`, `Local Contracts`, `Verification`): stop and ask the user where each belongs before continuing — usually a child or sub-root doc. Never silently delete them.
4. Re-download the pristine framework doc exactly as in section A step 1, and verify it exactly as in step 2.
5. Re-insert the saved content into the fresh doc: the `## User Preferences` body, the `## Child DOX Index` entries, and the feature bullets at the end of `## Feature Map`.
6. Report exactly what was restored, what was preserved, and what was moved where.
