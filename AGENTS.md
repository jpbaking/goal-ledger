# Goal Ledger repository instructions

Follow the
[Portable Agent Authoring](https://github.com/jpbaking/portable-agent-authoring)
guides — especially *Agent toolkit repositories* — for every skill or harness
change.

- Edit skills only under `.agents/skills/`.
- Regenerate `.claude/skills/` as byte-identical full-directory mirrors; never
  edit them independently.
- No skill may fetch this repository's files over raw HTTP.
- Keep each `SKILL.md` under 24,000 bytes (`agy` truncates beyond that; CI
  checks it). Move long templates or reference material into the skill's
  `references/`.
- Keep the distributable self-gating rule in
  `rules/shared/goal-ledger.md`; load it through one pointer per host.
- Keep planner/executor ownership and Git safety consistent across all five
  skills.
- Update `AGENT-INSTALL.md` and `README.md` whenever discovery, invocation, or
  installation changes.
- Run `python3 -m unittest discover -s tests -v` after changing the ledger
  validator or its contract.
- Dogfooding collision: with Goal Ledger installed globally, every harness also
  sees this repository's skills. Claude Code and Cline prefer the global copy
  (your edits seem to have no effect), Codex lists both, and Gemini CLI and
  OpenCode prefer the workspace copy. Test changes in a fresh session with the
  global copy temporarily removed or disabled.
