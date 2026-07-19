#!/usr/bin/env python3
"""Validate Goal Ledger files and, when available, their Git contract."""

from __future__ import print_function

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


PHASE_STATUS_RE = re.compile(
    r"^(todo|ongoing|done|skipped|needs-human)(?: — reason: (.+))?$"
)
GOAL_STATUSES = {
    "drafting",
    "approved",
    "executing",
    "blocked-on-human",
    "awaiting-acceptance",
    "completed",
    "abandoned",
}
TERMINAL_PHASE_STATUSES = {"done", "skipped"}
FULL_SHA_RE = re.compile(r"^[0-9a-fA-F]{40,64}$")
GOAL_ID_RE = re.compile(r"^\d{8}-[a-z0-9]+(?:-[a-z0-9]+)*$")
PHASE_ID_RE = re.compile(r"^phase-\d{4}$")


class LedgerValidator:
    def __init__(self, root, check_git=True):
        self.root = Path(root).resolve()
        self.ledger = self.root / ".goal-ledger"
        self.check_git = check_git
        self.errors = []
        self.warnings = []
        self.goal_fields = {}
        self.goal_phases = {}
        self.phase_data = {}

    def error(self, message):
        self.errors.append(message)

    def warn(self, message):
        self.warnings.append(message)

    @staticmethod
    def read_text(path):
        try:
            return path.read_text(encoding="utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("{} is not valid UTF-8: {}".format(path, exc))

    @staticmethod
    def field_map(text):
        fields = {}
        for match in re.finditer(r"(?m)^- ([A-Za-z][A-Za-z ]+): (.*)$", text):
            fields[match.group(1)] = match.group(2).strip()
        return fields

    @staticmethod
    def parse_status(value):
        match = PHASE_STATUS_RE.fullmatch(value)
        if not match:
            return None, None
        return match.group(1), match.group(2)

    def require_field(self, fields, name, context):
        value = fields.get(name)
        if value is None or value == "":
            self.error("{} is missing '{}'.".format(context, name))
            return ""
        return value

    def validate(self):
        if not self.ledger.is_dir():
            self.error("{} does not exist.".format(self.ledger))
            return self.result()
        self.validate_goal()
        self.validate_phase_files()
        self.validate_cross_file_state()
        self.validate_git_fields()
        if self.check_git:
            self.validate_git()
        return self.result()

    def validate_goal(self):
        goal_path = self.ledger / "GOAL.md"
        if not goal_path.is_file():
            self.error(".goal-ledger/GOAL.md is missing.")
            return
        try:
            text = self.read_text(goal_path)
        except ValueError as exc:
            self.error(str(exc))
            return
        self.goal_fields = self.field_map(text)

        goal_id = self.require_field(self.goal_fields, "Goal ID", "GOAL.md")
        if goal_id and not GOAL_ID_RE.fullmatch(goal_id):
            self.error("Goal ID must be YYYYMMDD-short-kebab-slug; got '{}'.".format(goal_id))

        for name in ("Outcome", "Done when", "Goal status", "Last completed phase"):
            self.require_field(self.goal_fields, name, "GOAL.md")
        goal_status = self.goal_fields.get("Goal status", "")
        if goal_status and goal_status not in GOAL_STATUSES:
            self.error("Unknown Goal status '{}'.".format(goal_status))

        repository = self.require_field(self.goal_fields, "Repository", "GOAL.md")
        if repository not in ("yes", "no"):
            self.error("Repository must be yes or no; got '{}'.".format(repository))
        for name in (
            "Strategy",
            "Starting branch",
            "Work branch",
            "Baseline commit",
            "Starting upstream at start",
            "Work upstream at start",
        ):
            self.require_field(self.goal_fields, name, "GOAL.md")
        for name in ("Current position", "Next action", "Last verified evidence", "Blockers"):
            self.require_field(self.goal_fields, name, "GOAL.md")

        phase_pattern = re.compile(
            r"(?m)^- \[([^\]]+)\] (phase-\d{4}) — (.+)$"
        )
        for match in phase_pattern.finditer(text):
            status_value, phase_id, title = match.groups()
            if phase_id in self.goal_phases:
                self.error("GOAL.md lists {} more than once.".format(phase_id))
            self.goal_phases[phase_id] = {"status_value": status_value, "title": title}
            status, reason = self.parse_status(status_value)
            if status is None:
                self.error("GOAL.md has invalid status '[{}]' for {}.".format(status_value, phase_id))
            elif status in ("skipped", "needs-human") and not reason:
                self.error("{} status requires '— reason: <why>'.".format(phase_id))

        if not 2 <= len(self.goal_phases) <= 7:
            self.error("GOAL.md must list 2–7 phases; found {}.".format(len(self.goal_phases)))

    def validate_phase_files(self):
        expected_files = {"GOAL.md"}
        expected_files.update("{}.md".format(phase_id) for phase_id in self.goal_phases)
        actual_entries = {entry.name for entry in self.ledger.iterdir()}
        extras = sorted(actual_entries - expected_files)
        missing = sorted(expected_files - actual_entries)
        if extras:
            self.error("Unexpected .goal-ledger entries: {}.".format(", ".join(extras)))
        if missing:
            self.error("Missing .goal-ledger entries: {}.".format(", ".join(missing)))

        ongoing_subtasks = []
        for phase_id in sorted(self.goal_phases):
            phase_path = self.ledger / "{}.md".format(phase_id)
            if not phase_path.is_file():
                continue
            try:
                text = self.read_text(phase_path)
            except ValueError as exc:
                self.error(str(exc))
                continue
            fields = self.field_map(text)
            heading = re.search(r"(?m)^# (phase-\d{4}) — (.+)$", text)
            if not heading:
                self.error("{} has an invalid heading.".format(phase_path.name))
                title = ""
            else:
                heading_id, title = heading.groups()
                if heading_id != phase_id:
                    self.error("{} heading identifies {}.".format(phase_path.name, heading_id))
                if title != self.goal_phases[phase_id]["title"]:
                    self.error("{} title does not match GOAL.md.".format(phase_id))

            status_value = self.require_field(fields, "Status", phase_path.name)
            status, reason = self.parse_status(status_value)
            if status is None:
                self.error("{} has invalid Status '{}'.".format(phase_path.name, status_value))
            elif status in ("skipped", "needs-human") and not reason:
                self.error("{} Status requires '— reason: <why>'.".format(phase_path.name))
            if status_value != self.goal_phases[phase_id]["status_value"]:
                self.error("{} Status does not match its GOAL.md mirror.".format(phase_id))

            depends = self.require_field(fields, "Depends on", phase_path.name)
            done_when = self.require_field(fields, "Done when", phase_path.name)
            self.require_field(fields, "Goal", phase_path.name)
            if done_when in ("<check>", "<runnable or observable check>"):
                self.error("{} still contains a placeholder Done when.".format(phase_path.name))

            dependencies = [] if depends == "none" else [item.strip() for item in depends.split(",")]
            for dependency in dependencies:
                if not PHASE_ID_RE.fullmatch(dependency):
                    self.error("{} has invalid dependency '{}'.".format(phase_id, dependency))

            subtask_pattern = re.compile(
                r"(?m)^(\d+)\. \[([^\]]+)\] (.+?) — done when: (.+)$"
            )
            subtasks = []
            for match in subtask_pattern.finditer(text):
                number, status_text, action, check = match.groups()
                sub_status, sub_reason = self.parse_status(status_text)
                if sub_status is None:
                    self.error("{} sub-task {} has invalid status '[{}]'.".format(phase_id, number, status_text))
                elif sub_status in ("skipped", "needs-human") and not sub_reason:
                    self.error("{} sub-task {} requires a reason.".format(phase_id, number))
                if not action.strip() or not check.strip() or check.strip() == "<check>":
                    self.error("{} sub-task {} lacks an observable check.".format(phase_id, number))
                if sub_status == "ongoing":
                    ongoing_subtasks.append("{} sub-task {}".format(phase_id, number))
                subtasks.append({"number": int(number), "status": sub_status})

            numbered_lines = re.findall(r"(?m)^\d+\. .+$", text)
            if len(numbered_lines) != len(subtasks):
                self.error("{} contains malformed numbered sub-task lines.".format(phase_path.name))
            if not 2 <= len(subtasks) <= 7:
                self.error("{} must contain 2–7 sub-tasks; found {}.".format(phase_path.name, len(subtasks)))
            if [item["number"] for item in subtasks] != list(range(1, len(subtasks) + 1)):
                self.error("{} sub-tasks must be numbered consecutively from 1.".format(phase_path.name))

            self.phase_data[phase_id] = {
                "status": status,
                "status_value": status_value,
                "dependencies": dependencies,
                "subtasks": subtasks,
            }

        if len(ongoing_subtasks) > 1:
            self.error("More than one sub-task is ongoing: {}.".format(", ".join(ongoing_subtasks)))

    def validate_cross_file_state(self):
        ongoing_phases = [
            phase_id for phase_id, data in self.phase_data.items() if data["status"] == "ongoing"
        ]
        if len(ongoing_phases) > 1:
            self.error("More than one phase is ongoing: {}.".format(", ".join(ongoing_phases)))

        for phase_id, data in self.phase_data.items():
            for dependency in data["dependencies"]:
                if dependency not in self.phase_data:
                    self.error("{} depends on missing {}.".format(phase_id, dependency))
                elif dependency == phase_id:
                    self.error("{} cannot depend on itself.".format(phase_id))

        visiting = set()
        visited = set()

        def visit(phase_id):
            if phase_id in visiting:
                self.error("Phase dependency cycle includes {}.".format(phase_id))
                return
            if phase_id in visited or phase_id not in self.phase_data:
                return
            visiting.add(phase_id)
            for dependency in self.phase_data[phase_id]["dependencies"]:
                visit(dependency)
            visiting.remove(phase_id)
            visited.add(phase_id)

        for phase_id in self.phase_data:
            visit(phase_id)

        last_completed = self.goal_fields.get("Last completed phase", "")
        done_phases = sorted(
            phase_id for phase_id, data in self.phase_data.items() if data["status"] == "done"
        )
        if done_phases and last_completed == "none":
            self.error("Last completed phase is none even though completed phases exist.")
        elif done_phases and last_completed not in ("", done_phases[-1]):
            self.error(
                "Last completed phase '{}' does not identify the latest done phase '{}'.".format(
                    last_completed, done_phases[-1]
                )
            )
        if last_completed != "none":
            if last_completed not in self.phase_data:
                self.error("Last completed phase '{}' does not exist.".format(last_completed))
            elif self.phase_data[last_completed]["status"] != "done":
                self.error("Last completed phase '{}' is not done.".format(last_completed))

        goal_status = self.goal_fields.get("Goal status", "")
        statuses = [data["status"] for data in self.phase_data.values()]
        for phase_id, data in self.phase_data.items():
            if data["status"] in ("ongoing", "done"):
                unsatisfied = [
                    dependency
                    for dependency in data["dependencies"]
                    if dependency in self.phase_data
                    and self.phase_data[dependency]["status"] not in TERMINAL_PHASE_STATUSES
                ]
                if unsatisfied:
                    self.error(
                        "{} is {} before dependencies are terminal: {}.".format(
                            phase_id, data["status"], ", ".join(unsatisfied)
                        )
                    )
            if data["status"] == "done":
                unfinished = [
                    item["number"]
                    for item in data["subtasks"]
                    if item["status"] not in TERMINAL_PHASE_STATUSES
                ]
                if unfinished:
                    self.error(
                        "{} is done but sub-tasks are unfinished: {}.".format(
                            phase_id, ", ".join(str(number) for number in unfinished)
                        )
                    )
        if goal_status in ("awaiting-acceptance", "completed"):
            nonterminal = [status for status in statuses if status not in TERMINAL_PHASE_STATUSES]
            if nonterminal:
                self.error("Goal status '{}' requires every phase to be done or skipped.".format(goal_status))
        if goal_status == "blocked-on-human" and "needs-human" not in statuses:
            blockers = self.goal_fields.get("Blockers", "none")
            if blockers == "none":
                self.warn("Goal is blocked-on-human but no phase or Handoff blocker records why.")
        if goal_status == "executing" and not ongoing_phases:
            self.warn("Goal is executing but no phase is currently ongoing; this is valid only at a phase boundary.")

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.root)] + list(args),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )

    def validate_git_fields(self):
        repository = self.goal_fields.get("Repository")
        strategy = self.goal_fields.get("Strategy")
        goal_status = self.goal_fields.get("Goal status")
        git_state_fields = (
            "Starting branch",
            "Work branch",
            "Baseline commit",
            "Starting upstream at start",
            "Work upstream at start",
        )
        if repository == "no":
            if strategy != "none":
                self.error("Repository no requires Strategy none.")
            for name in git_state_fields:
                if self.goal_fields.get(name) != "-":
                    self.error("Repository no requires '{}' to be '-'.".format(name))
            return
        if repository != "yes":
            return
        if strategy == "none":
            if goal_status not in ("drafting", "approved", "abandoned"):
                self.error("Goal status '{}' cannot use Strategy none.".format(goal_status))
            for name in git_state_fields:
                if self.goal_fields.get(name) != "-":
                    self.error("Unprepared Git strategy requires '{}' to be '-'.".format(name))
            return
        if strategy not in ("isolated-branch", "current-branch"):
            self.error("Unknown Git strategy '{}'.".format(strategy))
            return
        baseline = self.goal_fields.get("Baseline commit")
        if not baseline or not FULL_SHA_RE.fullmatch(baseline):
            self.error("Prepared Git strategy requires a full immutable Baseline commit.")
        for name in ("Starting branch", "Work branch"):
            if self.goal_fields.get(name) in (None, "", "-"):
                self.error("Prepared Git strategy requires '{}'.".format(name))

    def validate_git(self):
        repository = self.goal_fields.get("Repository")
        strategy = self.goal_fields.get("Strategy")
        goal_status = self.goal_fields.get("Goal status")
        baseline = self.goal_fields.get("Baseline commit")
        if repository != "yes":
            return

        inside = self.git("rev-parse", "--is-inside-work-tree")
        if inside.returncode != 0:
            self.error("GOAL.md says Repository yes, but the project is not in a readable Git worktree.")
            return
        head = self.git("rev-parse", "--verify", "HEAD")
        if head.returncode != 0:
            self.error("Git repository has no initial commit; create or authorize a baseline commit before Gate B.")
            return

        if strategy == "none":
            if goal_status == "approved":
                self.warn("Goal is approved but Git preparation has not completed yet.")
            return
        if strategy not in ("isolated-branch", "current-branch"):
            return
        if not baseline or not FULL_SHA_RE.fullmatch(baseline):
            return
        exists = self.git("cat-file", "-e", "{}^{{commit}}".format(baseline))
        if exists.returncode != 0:
            self.error("Baseline commit '{}' does not exist.".format(baseline))
            return
        ancestor = self.git("merge-base", "--is-ancestor", baseline, "HEAD")
        if ancestor.returncode != 0:
            self.error("Baseline commit is not an ancestor of HEAD.")

        branch = self.git("symbolic-ref", "--quiet", "--short", "HEAD")
        current_branch = branch.stdout.strip() if branch.returncode == 0 else "(detached)"
        work_branch = self.goal_fields.get("Work branch")
        if work_branch not in (None, "", "-") and current_branch != work_branch:
            self.warn("Current branch '{}' differs from Work branch '{}'.".format(current_branch, work_branch))

        log = self.git("log", "--format=%H%x1f%B%x1e", "{}..HEAD".format(baseline))
        if log.returncode != 0:
            self.error("Could not inspect commits after baseline: {}".format(log.stderr.strip()))
            return
        goal_id = self.goal_fields.get("Goal ID", "")
        for record in log.stdout.split("\x1e"):
            record = record.strip()
            if not record:
                continue
            parts = record.split("\x1f", 1)
            commit = parts[0]
            message = parts[1] if len(parts) == 2 else ""
            subject = message.splitlines()[0] if message else ""
            trailer_ids = re.findall(r"(?m)^Goal-ID: (.+)$", message)
            if subject.startswith("goal-ledger(") and goal_id not in trailer_ids:
                self.error("Framework commit {} lacks matching Goal-ID trailer.".format(commit[:12]))
            elif trailer_ids and goal_id not in trailer_ids:
                self.warn("Commit {} carries a foreign Goal-ID.".format(commit[:12]))
            elif not trailer_ids:
                self.warn("Commit {} is foreign to this goal and can prohibit squashing.".format(commit[:12]))
            phase_trailers = re.findall(r"(?m)^Goal-Phase: (phase-\d{4})$", message)
            for phase_id in phase_trailers:
                if phase_id not in self.phase_data:
                    self.error("Commit {} references unknown {}.".format(commit[:12], phase_id))

    def result(self):
        return {
            "valid": not self.errors,
            "errors": self.errors,
            "warnings": self.warnings,
            "phases": len(self.phase_data),
        }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Project root containing .goal-ledger")
    parser.add_argument("--no-git", action="store_true", help="Skip live Git repository checks")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    args = parser.parse_args(argv)

    validator = LedgerValidator(args.root, check_git=not args.no_git)
    result = validator.validate()
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        for message in result["errors"]:
            print("ERROR: {}".format(message))
        for message in result["warnings"]:
            print("WARNING: {}".format(message))
        if result["valid"]:
            print("Goal Ledger valid ({} phases, {} warnings).".format(result["phases"], len(result["warnings"])))
        else:
            print("Goal Ledger invalid ({} errors, {} warnings).".format(len(result["errors"]), len(result["warnings"])))
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    sys.exit(main())
