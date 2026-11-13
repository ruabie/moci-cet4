#!/usr/bin/env python3
"""LifeSim contract watchdog. Built-in Python only; no paid AI or browser required.

This checks whether the project is ready FOR QA, not whether gameplay has passed QA.
Source absence always creates a visible waiting_for_source report.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys

REQUIRED_MILESTONES = ("S0", "S1", "S2", "S3", "S4", "S5")
STATES = {"pending", "in_progress", "blocked", "done"}
EXPECTED_ENTRY = "lifesim/index.html"


def inspect(root: Path) -> dict:
    project = root / "lifesim"
    data = json.loads((project / "project.json").read_text(encoding="utf-8"))
    blockers = []
    if data.get("schemaVersion") != 1 or data.get("id") != "lifesim":
        blockers.append("Invalid LifeSim project ID/schema")
    if data.get("entry") != EXPECTED_ENTRY or data.get("activeTarget") != EXPECTED_ENTRY:
        blockers.append("Entry and Foreman target must remain LifeSim index.html")
    if data.get("stage") not in ("bootstrap", "prototype", "playable", "release_candidate"):
        blockers.append("Unknown project lifecycle stage")
    if data.get("limits", {}).get("maxRepairAttempts") != 2:
        blockers.append("Foreman attempt ceiling must remain two")
    if data.get("limits", {}).get("autoMerge") is not False:
        blockers.append("Auto-merging game changes is forbidden")
    if data.get("limits", {}).get("paidApiEnabled") is not False:
        blockers.append("Paid AI must remain opt-in and disabled")
    ms = data.get("milestones")
    if not isinstance(ms, list) or tuple(item.get("id") for item in ms if isinstance(item, dict)) != REQUIRED_MILESTONES:
        blockers.append("Milestone IDs must cover S0 through S5 in order")
        ms = []
    for item in ms:
        if not isinstance(item, dict):
            continue
        if item.get("status") not in STATES or not isinstance(item.get("required"), list) or not item.get("required"):
            blockers.append("Invalid milestone status or acceptance list: " + str(item.get("id")))
    path = root / EXPECTED_ENTRY
    has_source = path.is_file() and path.stat().st_size >= 1000
    # A tiny placeholder is not a playable source.
    source_bytes = path.stat().st_size if path.is_file() else 0
    completed = [x.get("id") for x in ms if x.get("status") == "done"]
    if completed and not has_source:
        blockers.append("Cannot mark milestones done without the actual game source")
    if data.get("stage") in ("playable", "release_candidate") and not has_source:
        blockers.append("Cannot claim playable/release without the actual game source")
    if has_source and data.get("sourceState") != "connected":
        blockers.append("Game source present but sourceState not updated to connected")
    if not has_source and data.get("sourceState") != "not_connected":
        blockers.append("Missing source must remain not_connected")
    if blockers:
        state = "blocked"
    elif not has_source:
        state = "waiting_for_source"
    else:
        state = "awaiting_browser_qa"
    return {
        "status": state,
        "project": data.get("id"),
        "sourceAvailable": has_source,
        "sourceBytes": source_bytes,
        "entry": EXPECTED_ENTRY,
        "completedMilestones": completed,
        "pendingMilestones": [x.get("id") for x in ms if x.get("status") != "done"],
        "blockers": blockers,
        "automatedGameplayApproved": False,
        "visualApproved": False,
        "freeModelsVerifiedOnUserPC": False,
        "note": "Bootstrap/contract success is not evidence that the game runs or is visually acceptable."
    }


def write_report(root: Path, report: dict) -> None:
    directory = root / "lifesim" / "qa" / "results"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "supervisor-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# LifeSim / 游戏计划书监工状态",
        "",
        "**当前状态：" + report["status"] + "**",
        "",
        "- 游戏源码已接入：" + ("是" if report["sourceAvailable"] else "否"),
        "- 真实浏览器游戏验收：尚未确认",
        "- 已完成里程碑：" + (", ".join(report["completedMilestones"]) or "无"),
        "- 仍待里程碑：" + ", ".join(report["pendingMilestones"]),
        "- 付费 API：禁用",
        "",
        "## 阻断问题",
        *["- " + v for v in report["blockers"]],
        "",
        "本报告仅为监工基础设施检查，未把缺少的游戏源码或未执行的测试误判为通过。",
    ]
    markdown = "\n".join(lines) + "\n"
    (directory / "supervisor-report.md").write_text(markdown, encoding="utf-8")
    if os.getenv("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(markdown)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    try:
        report = inspect(root)
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        report = {
            "status": "blocked", "project": "lifesim", "sourceAvailable": False,
            "sourceBytes": 0, "entry": EXPECTED_ENTRY,
            "completedMilestones": [], "pendingMilestones": list(REQUIRED_MILESTONES),
            "blockers": ["Failed to parse contract: " + str(error)],
            "automatedGameplayApproved": False, "visualApproved": False,
            "freeModelsVerifiedOnUserPC": False
        }
    write_report(root, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report["status"] == "blocked" else 0


if __name__ == "__main__":
    sys.exit(main())
