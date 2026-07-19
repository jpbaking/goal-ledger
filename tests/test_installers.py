import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def tree_digest(root):
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        digest.update(str(path.relative_to(root)).replace(os.sep, "/").encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def installer_environment(**overrides):
    env = os.environ.copy()
    env.update(
        {
            "GOAL_LEDGER_SOURCE": str(ROOT),
            "ASSUME_YES": "1",
            "WITH_CLINE": "0",
            "WITH_CLAUDE": "0",
            "WITH_AGENTS": "0",
            "WITH_GEMINI": "0",
        }
    )
    for key, value in overrides.items():
        if value is None:
            env.pop(key, None)
        else:
            env[key] = value
    return env


def make_source_archive(path):
    with zipfile.ZipFile(path, "w") as archive:
        for relative_root in (Path("rules"), Path("skills")):
            for source in (ROOT / relative_root).rglob("*"):
                if source.is_file() and "__pycache__" not in source.parts and source.suffix != ".pyc":
                    archive.write(source, Path("goal-ledger-source") / source.relative_to(ROOT))


class ShellInstallerTests(unittest.TestCase):
    def setUp(self):
        if os.name == "nt" or not shutil.which("sh"):
            self.skipTest("POSIX shell installer test")

    def run_installer(self, target, **env_overrides):
        return subprocess.run(
            ["sh", str(ROOT / "install.sh"), str(target)],
            env=installer_environment(**env_overrides),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_preserves_unowned_files_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(prefix="goal ledger test ") as directory:
            target = Path(directory)
            (target / ".agents" / "rules").mkdir(parents=True)
            (target / ".agents" / "rules" / "core.md").write_text("project owned\n", encoding="utf-8")
            (target / ".agents" / "rules" / "master-plan.md").write_text("other plan\n", encoding="utf-8")
            (target / ".claude" / "commands").mkdir(parents=True)
            legacy_command = target / ".claude" / "commands" / "master-plan-resume.md"
            legacy_command.write_text("other command\n", encoding="utf-8")
            (target / ".agents" / "skills" / "dox").mkdir(parents=True)
            (target / ".agents" / "skills" / "dox" / "SKILL.md").write_text("other skill\n", encoding="utf-8")
            (target / ".cline" / "skills" / "goal-ledger").mkdir(parents=True)
            duplicate = target / ".cline" / "skills" / "goal-ledger" / "SKILL.md"
            duplicate.write_text("other ledger\n", encoding="utf-8")
            agents = target / "AGENTS.md"
            agents.write_bytes("# Existing — café\n".encode("utf-8"))
            clineignore = target / ".clineignore"
            clineignore.write_text(".agents/\n", encoding="utf-8")

            result = self.run_installer(target, WITH_CLINE="1")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("left untouched", result.stdout)
            self.assertIn(".clineignore pattern", result.stdout)
            self.assertEqual((target / ".agents" / "rules" / "core.md").read_text(), "project owned\n")
            self.assertEqual((target / ".agents" / "rules" / "master-plan.md").read_text(), "other plan\n")
            self.assertEqual(legacy_command.read_text(encoding="utf-8"), "other command\n")
            self.assertEqual((target / ".agents" / "skills" / "dox" / "SKILL.md").read_text(), "other skill\n")
            self.assertEqual(duplicate.read_text(), "other ledger\n")
            self.assertEqual(clineignore.read_text(), ".agents/\n")
            self.assertIn("café", agents.read_text(encoding="utf-8"))
            self.assertIn(".agents/rules/goal-ledger.md", agents.read_text(encoding="utf-8"))
            validator = target / ".agents" / "skills" / "goal-ledger" / "scripts" / "validate_goal_ledger.py"
            self.assertTrue(validator.is_file())

            first = tree_digest(target)
            second_result = self.run_installer(target, WITH_CLINE="1")
            self.assertEqual(second_result.returncode, 0, second_result.stdout)
            self.assertEqual(tree_digest(target), first)

            stale = target / ".agents" / "skills" / "goal-ledger" / "stale.txt"
            stale.write_text("retired", encoding="utf-8")
            third_result = self.run_installer(target, WITH_CLINE="1")
            self.assertEqual(third_result.returncode, 0, third_result.stdout)
            self.assertFalse(stale.exists())

    def test_unfinished_master_plan_stops_before_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            scratch = target / ".tmp-agent-scratch"
            scratch.mkdir()
            (scratch / "MASTER-PLAN.md").write_text("- Plan status: active\n", encoding="utf-8")
            result = self.run_installer(target, WITH_CLINE="1")
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((target / ".agents").exists())

    def test_archive_is_validated_before_copy_and_staging_is_cleaned(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            target = fixture / "target"
            staging = fixture / "staging"
            target.mkdir()
            staging.mkdir()
            archive = fixture / "source.zip"
            make_source_archive(archive)
            result = self.run_installer(
                target,
                WITH_CLINE="1",
                GOAL_LEDGER_SOURCE=None,
                GOAL_LEDGER_ARCHIVE_URL=str(archive),
                TMPDIR=str(staging),
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertTrue((target / ".agents" / "skills" / "goal-ledger" / "SKILL.md").is_file())
            self.assertEqual(list(staging.iterdir()), [])

    def test_invalid_source_does_not_modify_target(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            target = fixture / "target"
            source = fixture / "invalid-source"
            target.mkdir()
            source.mkdir()
            sentinel = target / "sentinel.txt"
            sentinel.write_text("preserve", encoding="utf-8")
            result = self.run_installer(target, WITH_CLINE="1", GOAL_LEDGER_SOURCE=str(source))
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "preserve")
            self.assertFalse((target / ".agents").exists())

    def test_preexisting_backup_path_stops_before_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            rule = target / ".agents" / "rules" / "goal-ledger.md"
            rule.parent.mkdir(parents=True)
            rule.write_text("preserve old rule\n", encoding="utf-8")
            command = """
backup="$1/.agents/rules/goal-ledger.md.goal-ledger-backup.$$"
mkdir -p "$backup"
printf '%s\n' preserve > "$backup/sentinel"
exec sh "$2" "$1"
"""

            result = subprocess.run(
                ["sh", "-c", command, "backup-collision-test", str(target), str(ROOT / "install.sh")],
                env=installer_environment(WITH_CLINE="1"),
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )

            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("Temporary backup path already exists", result.stdout)
            self.assertEqual(rule.read_text(encoding="utf-8"), "preserve old rule\n")
            backups = list(rule.parent.glob("goal-ledger.md.goal-ledger-backup.*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / "sentinel").read_text(encoding="utf-8"), "preserve\n")

    def test_gemini_only_adds_gemini_bridge(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            result = self.run_installer(target, WITH_GEMINI="1")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertTrue((target / "GEMINI.md").is_file())
            self.assertFalse((target / "AGENTS.md").exists())
            self.assertTrue((target / ".agents" / "skills" / "goal-ledger" / "SKILL.md").is_file())

    def test_new_agents_file_matches_project_rules_shape(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)

            result = self.run_installer(target, WITH_AGENTS="1")

            self.assertEqual(result.returncode, 0, result.stdout)
            agents = (target / "AGENTS.md").read_text(encoding="utf-8")
            self.assertTrue(agents.startswith("# Project rules\n\n## Goal Ledger\n"))

    def test_appends_to_instruction_files_without_trailing_newline_idempotently(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            agents = target / "AGENTS.md"
            gemini = target / "GEMINI.md"
            agents.write_text("# Existing agents", encoding="utf-8")
            gemini.write_text("# Existing Gemini", encoding="utf-8")

            result = self.run_installer(target, WITH_AGENTS="1", WITH_GEMINI="1")

            self.assertEqual(result.returncode, 0, result.stdout)
            agents_after_first = agents.read_text(encoding="utf-8")
            gemini_after_first = gemini.read_text(encoding="utf-8")
            self.assertTrue(agents_after_first.startswith("# Existing agents\n\n## Goal Ledger\n"))
            self.assertEqual(gemini_after_first, "# Existing Gemini\n@.agents/rules/goal-ledger.md\n")

            second = self.run_installer(target, WITH_AGENTS="1", WITH_GEMINI="1")

            self.assertEqual(second.returncode, 0, second.stdout)
            self.assertEqual(agents.read_text(encoding="utf-8"), agents_after_first)
            self.assertEqual(gemini.read_text(encoding="utf-8"), gemini_after_first)

    def test_cline_and_claude_adapters_match_without_redundant_claude_import(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            result = self.run_installer(target, WITH_CLINE="1", WITH_CLAUDE="1")
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("byte-identical", result.stdout)
            self.assertEqual(
                tree_digest(target / ".agents" / "skills"),
                tree_digest(target / ".claude" / "skills"),
            )
            self.assertFalse((target / "CLAUDE.md").exists())

    def test_existing_redundant_claude_import_is_preserved_and_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            claude = target / "CLAUDE.md"
            original = "# Existing\n\n@.claude/rules/goal-ledger.md\n"
            claude.write_text(original, encoding="utf-8")

            result = self.run_installer(target, WITH_CLAUDE="1")

            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("redundant guidance", result.stdout)
            self.assertEqual(claude.read_text(encoding="utf-8"), original)

    def test_invalid_boolean_is_rejected_before_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            result = self.run_installer(target, WITH_CLINE="maybe")
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((target / ".agents").exists())

    def test_inherited_invalid_gemini_value_names_source_variable(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)

            result = self.run_installer(target, WITH_AGENTS="maybe", WITH_GEMINI=None)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("for WITH_AGENTS", result.stdout)
            self.assertNotIn("for WITH_GEMINI", result.stdout)


class PowerShellInstallerTests(unittest.TestCase):
    def powershells(self):
        candidates = []
        for name in ("powershell", "pwsh"):
            executable = shutil.which(name)
            if executable and executable not in candidates:
                candidates.append(executable)
        return candidates

    def run_installer(self, executable, target, **env_overrides):
        env = installer_environment(**env_overrides)
        env["GOAL_LEDGER_TARGET"] = str(target)
        return subprocess.run(
            [executable, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "install.ps1")],
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def test_preserves_utf8_and_copies_complete_skill(self):
        powershells = self.powershells()
        if not powershells:
            self.skipTest("PowerShell is unavailable")
        for executable in powershells:
            with self.subTest(executable=executable), tempfile.TemporaryDirectory(prefix="goal ledger ps ") as directory:
                target = Path(directory)
                agents = target / "AGENTS.md"
                original = "# Existing — café\r\n".encode("utf-8")
                agents.write_bytes(original)
                result = self.run_installer(executable, target, WITH_CLINE="1")
                self.assertEqual(result.returncode, 0, result.stdout)
                installed = agents.read_bytes()
                self.assertFalse(installed.startswith(b"\xef\xbb\xbf"))
                self.assertIn("café", installed.decode("utf-8"))
                self.assertTrue(
                    (target / ".agents" / "skills" / "goal-ledger" / "scripts" / "validate_goal_ledger.py").is_file()
                )

    def test_invalid_source_exits_nonzero_without_modifying_target(self):
        powershells = self.powershells()
        if not powershells:
            self.skipTest("PowerShell is unavailable")
        for executable in powershells:
            with self.subTest(executable=executable), tempfile.TemporaryDirectory() as directory:
                fixture = Path(directory)
                target = fixture / "target"
                source = fixture / "invalid-source"
                target.mkdir()
                source.mkdir()
                sentinel = target / "sentinel.txt"
                sentinel.write_text("preserve", encoding="utf-8")

                result = self.run_installer(
                    executable, target, WITH_CLINE="1", GOAL_LEDGER_SOURCE=str(source)
                )

                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(sentinel.read_text(encoding="utf-8"), "preserve")
                self.assertFalse((target / ".agents").exists())


if __name__ == "__main__":
    unittest.main()
