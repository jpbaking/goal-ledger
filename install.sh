#!/bin/sh
# Project-local installer/updater for Goal Ledger.
# Installs the Goal Ledger rule and skill family.

set -eu

GOAL_LEDGER_REPO="jpbaking/goal-ledger"
GOAL_LEDGER_REF="${GOAL_LEDGER_REF:-main}"
CONTENT_BASE="https://raw.githubusercontent.com/$GOAL_LEDGER_REPO/$GOAL_LEDGER_REF"
TARGET_ROOT="${1:-.}"

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if command -v curl >/dev/null 2>&1; then
  fetch() { mkdir -p "$(dirname "$2")"; curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { mkdir -p "$(dirname "$2")"; wget -q -O "$2" "$1"; }
else
  die "Neither curl nor wget found."
fi

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
    *) ask "$2" "$3" ;;
  esac
}

install_rule() {
  destination="$1"
  fetch "$CONTENT_BASE/rules/goal-ledger.md" "$TARGET_ROOT/$destination/goal-ledger.md"
}

install_skills() {
  destination="$1"
  for skill in goal-ledger goal-ledger-resume goal-ledger-status goal-ledger-abandon; do
    fetch "$CONTENT_BASE/skills/$skill/SKILL.md" \
      "$TARGET_ROOT/$destination/$skill/SKILL.md"
  done
}

remove_file() {
  [ ! -f "$TARGET_ROOT/$1" ] || rm -f "$TARGET_ROOT/$1"
}

remove_tree() {
  [ ! -d "$TARGET_ROOT/$1" ] || rm -rf "$TARGET_ROOT/$1"
}

cleanup_legacy_adapters() {
  for root in .agents .claude; do
    for component in core compose-helper dox lazyway-io-design master-plan; do
      remove_file "$root/rules/$component.md"
      remove_tree "$root/skills/$component"
    done
    for skill in dox-audit dox-child dox-fix dox-init dox-upgrade \
                 master-plan-resume master-plan-status master-plan-clear; do
      remove_tree "$root/skills/$skill"
    done
    for wrapper in compose-helper dox-audit dox-child dox-fix dox-init dox-upgrade \
                   lazyway-io-design master-plan master-plan-resume master-plan-status \
                   master-plan-clear; do
      remove_file "$root/commands/$wrapper.md"
      remove_file "$root/workflows/$wrapper.md"
    done
  done

  for component in 00-core-reasoning-rules core compose-helper dox lazyway-io-design master-plan plan-execute; do
    remove_file ".clinerules/$component.md"
  done
  for skill in compose-helper dox-audit dox-child dox-fix dox-init dox-upgrade \
               lazyway-io-design master-plan master-plan-resume master-plan-status \
               master-plan-clear plan-execute; do
    remove_tree ".cline/skills/$skill"
    remove_file ".clinerules/workflows/$skill.md"
  done
}

remove_claude_legacy_imports() {
  file="$TARGET_ROOT/CLAUDE.md"
  [ -f "$file" ] || return 0
  tmp_file="$(mktemp)"
  awk '
    $0 == "@.claude/rules/core.md" { next }
    $0 == "@.claude/rules/compose-helper.md" { next }
    $0 == "@.claude/rules/dox.md" { next }
    $0 == "@.claude/rules/lazyway-io-design.md" { next }
    $0 == "@.claude/rules/master-plan.md" { next }
    { print }
  ' "$file" > "$tmp_file"
  if ! cmp -s "$file" "$tmp_file"; then mv "$tmp_file" "$file"; else rm -f "$tmp_file"; fi
}

migrate_agents_pointer() {
  file="$TARGET_ROOT/AGENTS.md"
  [ -f "$file" ] || return 0
  tmp_file="$(mktemp)"
  awk '
    $0 == "## Agent rules (lazyway-io boilerplate)" {
      print "## Goal Ledger"
      next
    }
    $0 == "Read and follow `core.md` and `master-plan.md` in `.agents/rules/`." {
      print "Read and follow every Markdown file in `.agents/rules/`."
      next
    }
    { print }
  ' "$file" > "$tmp_file"
  if ! cmp -s "$file" "$tmp_file"; then mv "$tmp_file" "$file"; else rm -f "$tmp_file"; fi
}

check_legacy_active_plan() {
  file="$TARGET_ROOT/.tmp-agent-scratch/MASTER-PLAN.md"
  [ -f "$file" ] || return 0
  status="$(sed -n 's/^- Plan status: //p' "$file" | head -n 1)"
  if [ "$status" != "done" ]; then
    die "An unfinished legacy MASTER-PLAN exists in .tmp-agent-scratch/ (status: ${status:-unknown}). Resume, finish, abandon, or migrate it before upgrading; no files were changed."
  fi
  say "NOTE: completed legacy .tmp-agent-scratch/ left untouched; .goal-ledger/ is used for new goals."
}

allow_agents_for_cline() {
  file="$TARGET_ROOT/.clineignore"
  [ -f "$file" ] || return 0
  tmp_file="$(mktemp)"
  grep -vxF '.agents/' "$file" > "$tmp_file" || true
  if ! cmp -s "$file" "$tmp_file"; then mv "$tmp_file" "$file"; else rm -f "$tmp_file"; fi
}

[ -d "$TARGET_ROOT" ] || die "Target directory '$TARGET_ROOT' does not exist."

say "Goal Ledger — installer"
say "source: github.com/$GOAL_LEDGER_REPO@$GOAL_LEDGER_REF"
say "target: $TARGET_ROOT"
say ""
say "==> Which agent harnesses should this project support?"
cline_on=1;  decide "${WITH_CLINE:-}"  "    Cline (AGENTS.md + .agents/skills)?" y || cline_on=0
claude_on=1; decide "${WITH_CLAUDE:-}" "    Claude Code (CLAUDE.md + .claude/)?" y || claude_on=0
agents_on=1; decide "${WITH_AGENTS:-}" "    Codex / Antigravity / Gemini (AGENTS.md + .agents/)?" y || agents_on=0
[ "$cline_on$claude_on$agents_on" != "000" ] || die "Nothing selected — nothing to do."
say ""

check_legacy_active_plan

if [ "$cline_on" = "1" ] || [ "$agents_on" = "1" ]; then
  say "==> Shared AGENTS convention — Goal Ledger"
  install_rule ".agents/rules"
  install_skills ".agents/skills"

  AGENTS_MD="$TARGET_ROOT/AGENTS.md"
  if ! grep -qF '.agents/rules/' "$AGENTS_MD" 2>/dev/null; then
    cat >> "$AGENTS_MD" <<'EOF'

## Goal Ledger

Read and follow every Markdown file in `.agents/rules/`.
Reusable procedures live in `.agents/skills/`; use the matching skill when its
description applies.
EOF
  fi
  [ "$cline_on" != "1" ] || allow_agents_for_cline
  say "    installed .agents/{rules,skills} and preserved AGENTS.md"
  say ""
fi

if [ "$claude_on" = "1" ]; then
  say "==> Claude Code — Goal Ledger"
  install_rule ".claude/rules"
  install_skills ".claude/skills"

  CLAUDE_MD="$TARGET_ROOT/CLAUDE.md"
  if [ ! -f "$CLAUDE_MD" ]; then
    printf '%s\n\n' '# Project rules' > "$CLAUDE_MD"
  fi
  grep -qxF '@.claude/rules/goal-ledger.md' "$CLAUDE_MD" 2>/dev/null || \
    printf '%s\n' '@.claude/rules/goal-ledger.md' >> "$CLAUDE_MD"
  say "    installed .claude/{rules,skills} and preserved CLAUDE.md"
  say ""
fi

cleanup_legacy_adapters
remove_claude_legacy_imports
migrate_agents_pointer

say "Done. Installed the Goal Ledger rule and skill family into: $TARGET_ROOT"
say "Previously installed compose-helper scripts and DOX content inside AGENTS.md are left untouched; remove them manually if no longer wanted."
say "Ask your agent to use the goal-ledger skill for multi-phase work."
say "https://github.com/$GOAL_LEDGER_REPO#readme"
