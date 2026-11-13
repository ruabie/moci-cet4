"""Static visual verdict gate tests — does not require a local model."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "visual_review.py"
spec = importlib.util.spec_from_file_location("free_visual_review", MODULE)
V = importlib.util.module_from_spec(spec)
spec.loader.exec_module(V)


def example(verdict="pass", desktop="clear", mobile="clear", findings=None):
    return {
        "verdict": verdict, "desktop_road": desktop,
        "mobile_road": mobile, "findings": findings or [], "summary": "test"
    }


class VisualReviewTests(unittest.TestCase):
    def test_pass_is_only_precheck_not_release(self):
        report = V.normalize(example())
        self.assertEqual(report["status"], "visual_precheck_pass")
        self.assertFalse(report["final_release_approved"])
        self.assertIn("motion direction", report["not_verified"])

    def test_obstructed_road_blocks_even_if_model_says_pass(self):
        report = V.normalize(example(desktop="obstructed"))
        self.assertEqual(report["status"], "visual_precheck_block")

    def test_indeterminate_road_is_unknown_not_auto_approved(self):
        report = V.normalize(example(mobile="indeterminate"))
        self.assertEqual(report["status"], "visual_precheck_unknown")

    def test_block_finding_cannot_be_overridden_by_model_pass(self):
        result = example(findings=[{
            "severity": "block", "platform": "mobile", "observation": "huge wall",
            "next_check": "inspect camera"
        }])
        self.assertEqual(V.normalize(result)["status"], "visual_precheck_block")

    def test_malformed_verdict_is_rejected(self):
        with self.assertRaises(ValueError):
            V.normalize({"verdict": "perfect", "findings": []})

    def test_non_image_inputs_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            p = Path(temp) / "fake.png"
            p.write_text("not an image", encoding="utf-8")
            with self.assertRaises(ValueError):
                V.image_bytes(p)


if __name__ == "__main__":
    unittest.main()
