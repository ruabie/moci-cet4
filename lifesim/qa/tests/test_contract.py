"""No-cost LifeSim watchdog tests. A missing game source must never count as success."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "check_contract.py"
spec = importlib.util.spec_from_file_location("lifesim_contract", MODULE)
C = importlib.util.module_from_spec(spec)
spec.loader.exec_module(C)


class WatchdogTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "lifesim").mkdir()
        self.data = {
            "schemaVersion": 1, "id": "lifesim", "entry": "lifesim/index.html",
            "activeTarget": "lifesim/index.html", "stage": "bootstrap",
            "sourceState": "not_connected",
            "limits": {"maxRepairAttempts": 2, "autoMerge": False, "paidApiEnabled": False},
            "milestones": [
                {"id": "S" + str(i), "status": "pending", "required": ["check"]}
                for i in range(6)
            ],
        }
        self.save()

    def tearDown(self):
        self.tmp.cleanup()

    def save(self):
        (self.root / "lifesim" / "project.json").write_text(
            json.dumps(self.data), encoding="utf-8")

    def test_missing_game_not_approved(self):
        r = C.inspect(self.root)
        self.assertEqual(r["status"], "waiting_for_source")
        self.assertFalse(r["sourceAvailable"])
        self.assertFalse(r["automatedGameplayApproved"])
        self.assertFalse(r["visualApproved"])

    def test_a_tiny_placeholder_does_not_count_as_game(self):
        (self.root / "lifesim" / "index.html").write_text("<html></html>", encoding="utf-8")
        self.assertEqual(C.inspect(self.root)["status"], "waiting_for_source")

    def test_cannot_claim_finished_when_code_is_missing(self):
        self.data["stage"] = "playable"
        self.data["milestones"][0]["status"] = "done"
        self.save()
        r = C.inspect(self.root)
        self.assertEqual(r["status"], "blocked")
        self.assertTrue(r["blockers"])

    def test_cannot_switch_on_paid_api(self):
        self.data["limits"]["paidApiEnabled"] = True
        self.save()
        self.assertEqual(C.inspect(self.root)["status"], "blocked")

    def test_cannot_auto_merge(self):
        self.data["limits"]["autoMerge"] = True
        self.save()
        self.assertEqual(C.inspect(self.root)["status"], "blocked")

    def test_valid_source_still_needs_browser_qa(self):
        (self.root / "lifesim" / "index.html").write_text(
            "<!doctype html><html><body><canvas></canvas></body></html>" + ("x" * 1500),
            encoding="utf-8")
        self.data["sourceState"] = "connected"
        self.save()
        r = C.inspect(self.root)
        self.assertEqual(r["status"], "awaiting_browser_qa")
        self.assertFalse(r["automatedGameplayApproved"])

    def test_source_without_registration_is_blocked(self):
        (self.root / "lifesim" / "index.html").write_text("x" * 1500, encoding="utf-8")
        self.assertEqual(C.inspect(self.root)["status"], "blocked")

    def test_contract_change_cannot_escape_lifesim_target(self):
        self.data["activeTarget"] = "wordride/index.html"
        self.save()
        self.assertEqual(C.inspect(self.root)["status"], "blocked")


if __name__ == "__main__":
    unittest.main()
