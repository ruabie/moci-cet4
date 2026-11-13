"""Offline adversarial tests: no model subscription and no network access."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve()
spec = importlib.util.spec_from_file_location("free_foreman", HERE.parents[1] / "foreman.py")
F = importlib.util.module_from_spec(spec)
spec.loader.exec_module(F)

ANCHOR = "const eye=portrait?"
ORIGINAL = "<!doctype html><html><body><script>\nconst eye=portrait?1:8.8;\nconst pedal=42;\n</script></body></html>\n"
GOAL = "Prevent desktop building occlusion by keeping the camera in the road corridor"


def cmd(*args, cwd):
    subprocess.run(list(args), cwd=cwd, check=True, capture_output=True, text=True, timeout=20)


@unittest.skipUnless(shutil.which("git") and shutil.which("node"), "Requires Git and Node.js")
class ForemanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name) / "repo"
        root.mkdir()
        (root / "lifesim").mkdir()
        (root / "lifesim" / "index.html").write_text(ORIGINAL, encoding="utf-8")
        (root / ".gitignore").write_text("/.lifesim-foreman-state/\n", encoding="utf-8")
        cmd("git", "init", "-b", "main", cwd=root)
        cmd("git", "config", "user.name", "Foreman Test", cwd=root)
        cmd("git", "config", "user.email", "test@example.invalid", cwd=root)
        cmd("git", "add", ".", cwd=root)
        cmd("git", "commit", "-m", "baseline", cwd=root)
        self.root = root
        self.defaults = {key: getattr(F, key) for key in ("ROOT", "STATE", "TASKS", "WORKTREES")}
        F.ROOT = root
        F.STATE = root / ".foreman-state"
        F.TASKS = F.STATE / "tasks"
        F.WORKTREES = F.STATE / "worktrees"

    def tearDown(self):
        for key, value in self.defaults.items():
            setattr(F, key, value)
        self.temp.cleanup()

    def task(self):
        return F.new_task(GOAL, ANCHOR)

    @staticmethod
    def proposal(prompt, model):
        assert ANCHOR in prompt
        return {
            "old_text": "const eye=portrait?1:8.8;",
            "new_text": "const eye=portrait?1:3.0;",
            "rationale": "Road corridor guard"
        }

    def test_task_is_saved_and_requires_unique_anchor(self):
        task = self.task()
        self.assertEqual(F.load(task["id"])["state"], "queued")
        self.assertEqual(F.load(task["id"])["attempts"], 0)
        with self.assertRaises(F.ForemanError):
            F.new_task(GOAL, "not-present-anchor")
        with self.assertRaises(F.ForemanError):
            F.new_task("short", ANCHOR)

    def test_single_patch_modifies_worktree_not_main(self):
        task = self.task()
        done = F.run_task(task, "ollama", "mock", generator=self.proposal)
        path = F.worktree(done)
        self.assertEqual(done["state"], "candidate")
        self.assertEqual(done["attempts"], 1)
        self.assertIn("1:3.0", (path / F.TARGET).read_text())
        self.assertIn("1:8.8", (self.root / F.TARGET).read_text())
        self.assertEqual(F.git("diff", "--name-only", cwd=path), F.TARGET)

    def test_model_hallucination_never_overwrites_source(self):
        task = self.task()
        with self.assertRaises(F.ForemanError):
            F.run_task(task, "ollama", "mock", generator=lambda *_: {
                "old_text": "nonexistent substring here",
                "new_text": "replace everything",
            })
        self.assertEqual(F.load(task["id"])["state"], "waiting_resource")
        path = F.worktree(task)
        self.assertEqual((path / F.TARGET).read_text(), ORIGINAL)
        self.assertEqual(F.git("diff", "--name-only", cwd=path), "")

    def test_two_repair_attempts_then_blocked(self):
        task = self.task()
        task = F.run_task(task, "ollama", "mock", generator=self.proposal)
        task["state"] = "needs_repair"
        F.save(task)
        task = F.run_task(task, "ollama", "mock", generator=lambda *_: {
            "old_text": "const eye=portrait?1:3.0;",
            "new_text": "const eye=portrait?1:3.1;",
            "rationale": "Small follow-up revision",
        })
        self.assertEqual(task["attempts"], 2)
        task["state"] = "needs_repair"
        F.save(task)
        with self.assertRaises(F.ForemanError):
            F.run_task(task, "ollama", "mock", generator=self.proposal)
        self.assertEqual(F.load(task["id"])["state"], "blocked")

    def test_old_report_cannot_approve_new_candidate(self):
        task = self.task()
        task = F.run_task(task, "ollama", "mock", generator=self.proposal)
        with self.temp_report(task, sha="wrong-sha") as report:
            with self.assertRaises(F.ForemanError):
                F.review_task(task, report)
        task["state"] = "awaiting_qa"
        F.save(task)
        with self.temp_report(task, sha="wrong-sha") as report:
            with self.assertRaises(F.ForemanError):
                F.review_task(task, report)
        with self.temp_report(task, sha=F.git("rev-parse", "HEAD", cwd=F.worktree(task))) as report:
            updated = F.review_task(task, report)
            self.assertEqual(updated["state"], "technical_pass_visual_pending")

    def test_review_failure_schedules_one_more_repair(self):
        task = self.task()
        task = F.run_task(task, "ollama", "mock", generator=self.proposal)
        task["state"] = "awaiting_qa"
        F.save(task)
        with self.temp_report(task, sha=F.git("rev-parse", "HEAD", cwd=F.worktree(task)), passed=False) as report:
            updated = F.review_task(task, report)
        self.assertEqual(updated["state"], "needs_repair")

    from contextlib import contextmanager

    @contextmanager
    def temp_report(self, task, sha, passed=True):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "report.json"
            path.write_text(json.dumps({
                "status": "technical-pass" if passed else "blocked",
                "blockers": [] if passed else ["Intentional test failure"],
                "sourceBranch": task["branch"],
                "sourceHeadSha": sha,
            }), encoding="utf-8")
            yield path


if __name__ == "__main__":
    unittest.main()
