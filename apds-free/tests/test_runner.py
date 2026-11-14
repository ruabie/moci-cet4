"""Security and recovery tests; never use an LLM or a paid API."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE_PATH = Path(__file__).resolve().parents[1] / "runner.py"
spec = importlib.util.spec_from_file_location("apds_runner", MODULE_PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class CoordinatorTests(unittest.TestCase):
    def test_scope_rejects_paths_and_other_projects(self):
        for path in ("wordride/index.html", "kotoba/a.gd",
                     "lifesim/godot/../../wordride/hack.gd",
                     "lifesim/godot/a.py", "lifesim/godot\\oops.gd"):
            with self.assertRaises(ValueError, msg=path):
                runner.safe_path(path)

    def test_patch_must_be_unique_and_nonempty(self):
        with self.assertRaises(ValueError):
            runner.apply_exact_patch("a a", {"old": "a", "new": "b"})
        with self.assertRaises(ValueError):
            runner.apply_exact_patch("a", {"old": "", "new": "b"})
        self.assertEqual(runner.apply_exact_patch("abc", {"old": "b", "new": "X"}), "aXc")

    def test_duplicate_or_out_of_scope_tasks_rejected(self):
        t = {"id": "a", "kind": "file_exists", "path": "lifesim/godot/project.godot"}
        with self.assertRaises(ValueError):
            runner.validate_tasks({"tasks": [t, t]})
        with self.assertRaises(ValueError):
            runner.validate_tasks({"tasks": [{"id": "x", "kind": "edit",
                                               "path": "wordride/a.gd", "goal": "x"}]})

    def test_missing_source_blocks_without_model_call(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            tasks = [{"id": "gate", "kind": "file_exists",
                      "path": "lifesim/godot/project.godot"}]
            state = {"tasks": {}}
            tid, outcome = runner.step(tasks, state, root=root,
                                       model_fn=lambda *a: self.fail("should not call model"),
                                       local=root / ".local")
            self.assertEqual((tid, outcome), ("gate", "waiting_for_source"))
            self.assertEqual(state["tasks"]["gate"]["status"], "waiting_for_source")
            p = root / "lifesim" / "godot" / "project.godot"
            p.parent.mkdir(parents=True)
            p.write_text("config_version=5")
            self.assertEqual(runner.step(tasks, state, root=root, local=root / ".local")[1], "passed")

    def test_candidate_is_isolated_and_stops_after_one_success(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "lifesim/godot/scripts/player.gd"
            path.parent.mkdir(parents=True)
            path.write_text("extends Node\nvar speed = 1\n", encoding="utf-8")
            t = [{"id": "fix1", "kind": "edit",
                  "path": "lifesim/godot/scripts/player.gd", "goal": "Set speed to 2"}]
            calls = []
            def fake(task, source, error):
                calls.append(1)
                return {"old": "speed = 1", "new": "speed = 2"}
            state = {"tasks": {}}
            local = root / ".local"
            self.assertEqual(runner.step(t, state, root=root, model_fn=fake,
                                         local=local)[1], "proposal_ready")
            self.assertEqual(path.read_text(), "extends Node\nvar speed = 1\n")
            self.assertIn("speed = 2", (local / "proposals/fix1.candidate.gd").read_text())
            self.assertEqual(runner.step(t, state, root=root, model_fn=fake,
                                         local=local)[1], "no_action")
            self.assertEqual(len(calls), 1)

    def test_failed_model_never_modifies_source_and_is_bounded(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            path = root / "lifesim/godot/a.gd"
            path.parent.mkdir(parents=True)
            path.write_text("original")
            count = []
            def invalid(*args):
                count.append(1)
                return {"old": "nonexistent", "new": "bad"}
            state = {"tasks": {}}
            status = runner.step([{"id":"bad", "kind":"edit",
                                   "path":"lifesim/godot/a.gd", "goal":"Fix"}],
                                 state, root=root, model_fn=invalid,
                                 local=root / ".local")[1]
            self.assertEqual(status, "blocked")
            self.assertEqual(len(count), 2)
            self.assertEqual(path.read_text(), "original")


if __name__ == "__main__":
    unittest.main()
