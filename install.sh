#!/bin/sh
# Project-local installer/updater for Goal Ledger.
# Downloads one complete source archive, validates it, and installs from it.

set -eu

GOAL_LEDGER_REPO="${GOAL_LEDGER_REPO:-jpbaking/goal-ledger}"
GOAL_LEDGER_REF="${GOAL_LEDGER_REF:-main}"
TARGET_ROOT="${1:-.}"
STAGING_ROOT=""
SOURCE_ROOT=""
ACTIVE_INCOMING=""
ACTIVE_BACKUP=""

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [ -n "$ACTIVE_INCOMING" ] && [ -e "$ACTIVE_INCOMING" ]; then
    if [ -d "$ACTIVE_INCOMING" ]; then rm -rf "$ACTIVE_INCOMING"; else rm -f "$ACTIVE_INCOMING"; fi
  fi
  if [ -n "$ACTIVE_BACKUP" ] && [ -e "$ACTIVE_BACKUP" ]; then
    say "WARNING: interrupted install backup left at $ACTIVE_BACKUP"
  fi
  [ -z "$STAGING_ROOT" ] || [ ! -d "$STAGING_ROOT" ] || rm -rf "$STAGING_ROOT"
}

on_signal() {
  cleanup
  trap - EXIT
  exit "$1"
}

trap cleanup EXIT
trap 'on_signal 129' HUP
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

ask() {
  question="$1"; default="${2:-n}"
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    say "$question [auto-yes via ASSUME_YES=1]"
    return 0
  fi
  if ! ( : < /dev/tty > /dev/tty ) 2>/dev/null; then
    say "$question [no terminal — defaulting to $default]"
    [ "$default" = "y" ]
    return
  fi
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while :; do
    printf '%s %s ' "$question" "$hint" > /dev/tty
    IFS= read -r answer < /dev/tty || answer=""
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      "") [ "$default" = "y" ]; return ;;
    esac
  done
}

decide() {
  case "$1" in
    1) return 0 ;;
    0) return 1 ;;
    "") ask "$2" "$3" ;;
    *) die "Expected 1 or 0 for $4; got '$1'." ;;
  esac
}

download() {
  if [ -f "$1" ]; then
    cp "$1" "$2"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    die "Neither curl nor wget found."
  fi
}

prepare_source() {
  if [ -n "${GOAL_LEDGER_SOURCE:-}" ]; then
    [ -d "$GOAL_LEDGER_SOURCE" ] || die "GOAL_LEDGER_SOURCE '$GOAL_LEDGER_SOURCE' is not a directory."
    SOURCE_ROOT="$GOAL_LEDGER_SOURCE"
    say "source: local directory $SOURCE_ROOT"
    return
  fi

  command -v unzip >/dev/null 2>&1 || die "unzip is required to install the GitHub project archive."
  STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/goal-ledger-install.XXXXXX")"
  archive="$STAGING_ROOT/source.zip"
  extracted="$STAGING_ROOT/source"
  mkdir -p "$extracted"
  encoded_ref="$(printf '%s' "$GOAL_LEDGER_REF" | sed 's|%|%25|g; s|/|%2F|g')"
  archive_url="${GOAL_LEDGER_ARCHIVE_URL:-https://api.github.com/repos/$GOAL_LEDGER_REPO/zipball/$encoded_ref}"
  say "source: github.com/$GOAL_LEDGER_REPO@$GOAL_LEDGER_REF"
  download "$archive_url" "$archive"
  unzip -q "$archive" -d "$extracted"
  set -- "$extracted"/*
  if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    die "Downloaded archive did not contain exactly one project directory."
  fi
  SOURCE_ROOT="$1"
}

validate_source() {
  [ -f "$SOURCE_ROOT/rules/goal-ledger.md" ] || die "Source is missing rules/goal-ledger.md."
  [ -f "$SOURCE_ROOT/skills/goal-ledger/scripts/validate_goal_ledger.py" ] || \
    die "Source is missing the Goal Ledger validator script."
  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    skill_file="$SOURCE_ROOT/skills/$skill/SKILL.md"
    [ -f "$skill_file" ] || die "Source is missing skills/$skill/SKILL.md."
    skill_name="$(sed -n 's/^name:[[:space:]]*//p' "$skill_file" | head -n 1)"
    [ "$skill_name" = "$skill" ] || die "Skill name '$skill_name' does not match directory '$skill'."
    grep -q '^description:' "$skill_file" || die "Skill '$skill' has no description."
  done
}

install_file() {
  file_source="$1"; file_destination="$TARGET_ROOT/$2"
  file_parent="$(dirname "$file_destination")"
  file_incoming="$file_destination.goal-ledger-install.$$"
  file_backup="$file_destination.goal-ledger-backup.$$"
  mkdir -p "$file_parent"
  [ ! -d "$file_destination" ] || die "Expected file destination but found directory: $file_destination"
  [ ! -e "$file_incoming" ] || die "Temporary installation path already exists: $file_incoming"
  [ ! -e "$file_backup" ] || die "Temporary backup path already exists: $file_backup"
  ACTIVE_INCOMING="$file_incoming"
  ACTIVE_BACKUP="$file_backup"
  cp "$file_source" "$file_incoming"
  if [ -e "$file_destination" ]; then mv "$file_destination" "$file_backup"; fi
  if mv "$file_incoming" "$file_destination"; then
    [ ! -e "$file_backup" ] || rm -f "$file_backup"
    ACTIVE_INCOMING=""
    ACTIVE_BACKUP=""
  else
    [ ! -e "$file_backup" ] || mv "$file_backup" "$file_destination"
    ACTIVE_BACKUP=""
    die "Could not install $file_destination."
  fi
}

install_tree() {
  tree_source="$1"; tree_destination="$TARGET_ROOT/$2"
  tree_parent="$(dirname "$tree_destination")"
  tree_incoming="$tree_destination.goal-ledger-install.$$"
  tree_backup="$tree_destination.goal-ledger-backup.$$"
  mkdir -p "$tree_parent"
  [ ! -e "$tree_incoming" ] || die "Temporary installation path already exists: $tree_incoming"
  [ ! -e "$tree_backup" ] || die "Temporary backup path already exists: $tree_backup"
  ACTIVE_INCOMING="$tree_incoming"
  ACTIVE_BACKUP="$tree_backup"
  cp -R "$tree_source" "$tree_incoming"
  if [ -e "$tree_destination" ]; then mv "$tree_destination" "$tree_backup"; fi
  if mv "$tree_incoming" "$tree_destination"; then
    [ ! -e "$tree_backup" ] || rm -rf "$tree_backup"
    ACTIVE_INCOMING=""
    ACTIVE_BACKUP=""
  else
    [ ! -e "$tree_backup" ] || mv "$tree_backup" "$tree_destination"
    ACTIVE_BACKUP=""
    die "Could not install $tree_destination."
  fi
}

install_rule() {
  install_file "$SOURCE_ROOT/rules/goal-ledger.md" "$1/goal-ledger.md"
}

install_skills() {
  skills_destination="$1"
  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    install_tree "$SOURCE_ROOT/skills/$skill" "$skills_destination/$skill"
  done
}

check_legacy_active_plan() {
  file="$TARGET_ROOT/.tmp-agent-scratch/MASTER-PLAN.md"
  [ -f "$file" ] || return 0
  status="$(sed -n 's/^- Plan status: //p' "$file" | head -n 1)"
  if [ "$status" != "done" ]; then
    die "An unfinished legacy MASTER-PLAN exists in .tmp-agent-scratch/ (status: ${status:-unknown}). Resume, finish, abandon, or migrate it before installing; no files were changed."
  fi
  say "NOTE: completed legacy .tmp-agent-scratch/ left untouched."
}

inspect_same_named_artifacts() {
  for path in \
    .agents/rules/master-plan.md .claude/rules/master-plan.md .clinerules/master-plan.md \
    .agents/skills/master-plan .agents/skills/master-plan-resume \
    .agents/skills/master-plan-status .agents/skills/master-plan-clear \
    .claude/skills/master-plan .claude/skills/master-plan-resume \
    .claude/skills/master-plan-status .claude/skills/master-plan-clear \
    .cline/skills/master-plan .cline/skills/master-plan-resume \
    .cline/skills/master-plan-status .cline/skills/master-plan-clear \
    .claude/commands/master-plan.md .claude/commands/master-plan-resume.md \
    .claude/commands/master-plan-status.md .claude/commands/master-plan-clear.md \
    .clinerules/workflows/master-plan.md .clinerules/workflows/master-plan-resume.md \
    .clinerules/workflows/master-plan-status.md .clinerules/workflows/master-plan-clear.md; do
    if [ -e "$TARGET_ROOT/$path" ]; then
      say "NOTE: existing $path is not owned by this installer and will be left untouched."
    fi
  done

  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    for root in .agents .claude; do
      if [ -e "$TARGET_ROOT/$root/skills/$skill" ]; then
        say "NOTE: existing $root/skills/$skill is a same-named installation destination and will be refreshed if selected."
      fi
    done
    if [ -e "$TARGET_ROOT/.cline/skills/$skill" ]; then
      say "WARNING: existing .cline/skills/$skill is left untouched and may duplicate .agents/skills/$skill in Cline."
    fi
  done

  for root in .agents .claude; do
    if [ -e "$TARGET_ROOT/$root/rules/goal-ledger.md" ]; then
      say "NOTE: existing $root/rules/goal-ledger.md is a same-named installation destination and will be refreshed if selected."
    fi
  done
}

inspect_global_collisions() {
  [ -n "${HOME:-}" ] || return 0
  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    for root in \
      "$HOME/.agents/skills" "$HOME/.cline/skills" "$HOME/.claude/skills" \
      "$HOME/.gemini/skills" "$HOME/.gemini/config/skills"; do
      if [ -e "$root/$skill" ]; then
        say "WARNING: global $root/$skill may shadow or duplicate the project skill; verify the selected harness resolves the project adapter."
      fi
    done
  done
}

ensure_agents_pointer() {
  file="$TARGET_ROOT/AGENTS.md"
  if [ -f "$file" ] && grep -qF '.agents/rules/goal-ledger.md' "$file"; then return; fi
  if [ ! -f "$file" ]; then printf '%s\n' '# Project rules' > "$file"; fi
  if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$file"
  fi
  cat >> "$file" <<'EOF'

## Goal Ledger

Read and follow `.agents/rules/goal-ledger.md`.
Reusable procedures live in `.agents/skills/`; use the matching skill when its
description applies.
EOF
}

ensure_gemini_pointer() {
  file="$TARGET_ROOT/GEMINI.md"
  if [ ! -f "$file" ]; then printf '%s\n\n' '# Project context' > "$file"; fi
  if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l | tr -d ' ')" -eq 0 ]; then
    printf '\n' >> "$file"
  fi
  grep -qxF '@.agents/rules/goal-ledger.md' "$file" 2>/dev/null || \
    printf '%s\n' '@.agents/rules/goal-ledger.md' >> "$file"
}

warn_clineignore() {
  file="$TARGET_ROOT/.clineignore"
  [ -f "$file" ] || return 0
  pattern="$(sed -n '/^[[:space:]]*[#!]/d; /^[[:space:]]*$/d; /\.agents/p' "$file" | head -n 1)"
  if [ -n "$pattern" ]; then
    say "WARNING: .clineignore pattern '$pattern' may restrict access to the canonical .agents content; it was preserved. Review the rule and verify Cline can load and use Goal Ledger."
  fi
}

warn_redundant_claude_import() {
  file="$TARGET_ROOT/CLAUDE.md"
  [ -f "$file" ] || return 0
  if grep -qxF '@.claude/rules/goal-ledger.md' "$file"; then
    say "WARNING: CLAUDE.md imports @.claude/rules/goal-ledger.md, which Claude also auto-discovers in .claude/rules. The existing line was preserved; remove it after review to avoid redundant guidance."
  fi
}

verify_overlapping_skill_copies() {
  [ "$cline_on" = "1" ] && [ "$claude_on" = "1" ] || return 0
  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    diff -qr "$TARGET_ROOT/.agents/skills/$skill" "$TARGET_ROOT/.claude/skills/$skill" >/dev/null || \
      die "Overlapping Cline/Claude adapters differ for skill '$skill'."
  done
  say "NOTE: Cline and Claude require overlapping discovery adapters. Copies are byte-identical; confirm Cline's skill list exposes each Goal Ledger name once."
}

[ -d "$TARGET_ROOT" ] || die "Target directory '$TARGET_ROOT' does not exist."

say "Goal Ledger — installer"
say "target: $TARGET_ROOT"
say ""
say "==> Which agent harnesses should this project support?"
cline_on=1;  decide "${WITH_CLINE:-}"  "    Cline (AGENTS.md + .agents/skills)?" y WITH_CLINE || cline_on=0
claude_on=1; decide "${WITH_CLAUDE:-}" "    Claude Code (.claude/rules + .claude/skills)?" y WITH_CLAUDE || claude_on=0
agents_on=1; decide "${WITH_AGENTS:-}" "    Codex / Antigravity (AGENTS.md + .agents/)?" y WITH_AGENTS || agents_on=0
if [ "${WITH_GEMINI+x}" = "x" ]; then
  gemini_value="$WITH_GEMINI"; gemini_variable=WITH_GEMINI
else
  gemini_value="${WITH_AGENTS:-}"; gemini_variable=WITH_AGENTS
fi
gemini_on=1; decide "$gemini_value" "    Gemini CLI (GEMINI.md + .agents/skills)?" y "$gemini_variable" || gemini_on=0
[ "$cline_on$claude_on$agents_on$gemini_on" != "0000" ] || die "Nothing selected — nothing to do."
say ""

check_legacy_active_plan
prepare_source
validate_source
inspect_same_named_artifacts
inspect_global_collisions

if [ "$cline_on" = "1" ] || [ "$agents_on" = "1" ] || [ "$gemini_on" = "1" ]; then
  say "==> Shared .agents convention — Goal Ledger"
  install_rule ".agents/rules"
  install_skills ".agents/skills"
  [ "$cline_on" != "1" ] || warn_clineignore
  if [ "$cline_on" = "1" ] || [ "$agents_on" = "1" ]; then ensure_agents_pointer; fi
  [ "$gemini_on" != "1" ] || ensure_gemini_pointer
  say "    installed .agents/{rules,skills} and preserved root instruction files"
  say ""
fi

if [ "$claude_on" = "1" ]; then
  say "==> Claude Code — Goal Ledger"
  install_rule ".claude/rules"
  install_skills ".claude/skills"
  warn_redundant_claude_import
  say "    installed auto-discovered .claude/{rules,skills} and preserved CLAUDE.md"
  say ""
fi

verify_overlapping_skill_copies

say "Done. Installed the Goal Ledger rule and skill family into: $TARGET_ROOT"
say "Unrelated and legacy files were inspected but left untouched."
say "Ask your agent to use the goal-ledger skill for multi-phase work."
say "https://github.com/$GOAL_LEDGER_REPO#readme"
