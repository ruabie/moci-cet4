#!/usr/bin/env python3
"""APDS Free: local-only, fail-closed task coordinator (Python standard library)."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
LOCAL = HERE / ".local"
TASKS_FILE = HERE / "tasks.json"
STATE_FILE = LOCAL / "state.json"
LOCK = LOCAL / "run.lock"
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"  # Deliberately not configurable.
MODEL = "qwen2.5-coder:3b"
MAX_ATTEMPTS = 2
ALLOWED_PREFIX = "lifesim/godot/"
MAX_SOURCE_CHARS = 20000


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def load_json(path, default=None):
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".tmp-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(value, f, ensure_ascii=False, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def safe_path(relative, *, gate=False, root=ROOT):
    if not isinstance(relative, str) or "\\" in relative:
        raise ValueError("invalid path")
    parts = PurePosixPath(relative).parts
    if not parts or any(p in ("..", ".") for p in parts):
        raise ValueError("path traversal refused")
    if not relative.startswith(ALLOWED_PREFIX):
        raise ValueError("outside approved LifeSim Godot directory")
    if not gate and PurePosixPath(relative).suffix != ".gd":
        raise ValueError("only Godot .gd scripts may be edited")
    absolute = (root / Path(*parts)).resolve()
    approved = (root / "lifesim" / "godot").resolve()
    if not absolute.is_relative_to(approved):
        raise ValueError("symlink or path escaped the approved directory")
    return absolute


def validate_tasks(raw):
    if not isinstance(raw, dict) or not isinstance(raw.get("tasks"), list):
        raise ValueError("tasks.json must contain a tasks array")
    ids = set()
    for task in raw["tasks"]:
        if not isinstance(task, dict):
            raise ValueError("task must be an object")
        tid = task.get("id")
        if not isinstance(tid, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,60}", tid):
            raise ValueError("unsafe task ID")
        if tid in ids:
            raise ValueError("duplicate task ID")
        ids.add(tid)
        if task.get("kind") not in ("file_exists", "edit"):
            raise ValueError("unsupported task kind")
        safe_path(task.get("path"), gate=(task["kind"] == "file_exists"))
        if task["kind"] == "edit":
            goal = task.get("goal")
            if not isinstance(goal, str) or not 0 < len(goal) <= 1000:
                raise ValueError("edit task requires short goal")
    return raw["tasks"]


def apply_exact_patch(source, patch):
    if not isinstance(patch, dict) or set(patch) != {"old", "new"}:
        raise ValueError("response must have exactly old and new")
    old, new = patch["old"], patch["new"]
    if not isinstance(old, str) or not isinstance(new, str) or not old or old == new:
        raise ValueError("invalid replacement")
    if len(old) > 6000 or len(new) > 6000 or source.count(old) != 1:
        raise ValueError("replacement must uniquely match existing source")
    candidate = source.replace(old, new, 1)
    if len(candidate) > MAX_SOURCE_CHARS + 6000:
        raise ValueError("result too large")
    return candidate


def propose_edit(task, source, reason=""):
    prompt = (
        "You are producing ONE constrained text replacement for a Godot script. "
        "Return ONLY compact JSON with keys old and new. The old string MUST be an "
        "exact, unique substring of SOURCE. Never output commands or file paths. "
        "Make the smallest change that meets GOAL.\n"
        "GOAL:\n" + task["goal"] + "\n"
        "PREVIOUS ERROR:\n" + reason[:1000] + "\nSOURCE:\n" + source
    )
    body = json.dumps({"model": MODEL, "prompt": prompt, "stream": False,
                       "options": {"temperature": 0.1, "num_predict": 2048}}).encode()
    request = urllib.request.Request(OLLAMA_URL, data=body,
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.geturl() != OLLAMA_URL:
            raise RuntimeError("redirected endpoint refused")
        payload = json.loads(response.read(65537))
    answer = payload.get("response")
    if not isinstance(answer, str):
        raise ValueError("Ollama response missing")
    return json.loads(answer.strip())


def step(tasks, state, root=ROOT, model_fn=propose_edit, local=LOCAL):
    """Perform one bounded unit; never execute model-generated code."""
    records = state.setdefault("tasks", {})
    for task in tasks:
        if task.get("enabled") is False:
            continue
        tid = task["id"]
        record = records.setdefault(tid, {"status": "ready", "attempts": 0})
        if record["status"] in ("passed", "proposal_ready", "blocked"):
            continue
        path = safe_path(task["path"], gate=(task["kind"] == "file_exists"), root=root)
        if not path.is_file():
            record.update(status="waiting_for_source",reason="Required source is not in GitHub/worktree")
            return tid, "waiting_for_source"
        if task["kind"] == "file_exists":
            record.update(status="passed",reason="File exists only; engine runtime NOT verified")
            return tid, "passed"
        source = path.read_text(encoding="utf-8")
        if len(source) > MAX_SOURCE_CHARS:
            record.update(status="blocked",reason="Source exceeds bounded model context")
            return tid, "blocked"
        error = ""
        for attempt in range(MAX_ATTEMPTS):
            record["attempts"] = attempt + 1
            try:
                candidate = apply_exact_patch(source, model_fn(task, source, error))
                evidence = {
                    "task_id": tid, "status": "unverified_proposal",
                    "path": task["path"], "base_sha256": digest(source),
                    "candidate_sha256": digest(candidate),
                    "note": "Candidate only. Not tested, not committed, not published."
                }
                proposals = local / "proposals"
                proposals.mkdir(parents=True, exist_ok=True)
                (proposals / (tid + ".candidate.gd")).write_text(candidate,encoding="utf-8")
                save_json(proposals / (tid + ".evidence.json"), evidence)
                record.update(status="proposal_ready", reason="Isolated candidate; CI/runtime pending")
                return tid, "proposal_ready"
            except (ValueError, OSError, RuntimeError, TimeoutError) as exc:
                error = str(exc)[:1000]
            except Exception as exc:
                error = "Model unavailable or invalid response: " + type(exc).__name__
        record.update(status="blocked", reason=error or "Two failed attempts")
        return tid, "blocked"
    return None, "no_action"


def run_once():
    LOCAL.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        print(json.dumps({"status": "locked", "note": "Another run or stale lock; no mutation"}))
        return 2
    try:
        with os.fdopen(fd, "w") as f:
            f.write(str(os.getpid()))
        tasks = validate_tasks(load_json(TASKS_FILE, {"tasks": []}))
        state = load_json(STATE_FILE, {"schema": 1, "tasks": {}})
        tid, outcome = step(tasks, state)
        save_json(STATE_FILE, state)
        print(json.dumps({"task": tid, "status": outcome}, ensure_ascii=False))
        return 0 if outcome != "blocked" else 1
    finally:
        LOCK.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description="Local-only, zero-paid-API APDS pilot")
    parser.add_argument("--once", action="store_true", help="Process one bounded task")
    parser.add_argument("--status", action="store_true", help="Print persisted state")
    args = parser.parse_args()
    if args.status or not args.once:
        state = load_json(STATE_FILE, {"schema": 1, "tasks": {}})
        print(json.dumps({"source_present": (ROOT / "lifesim/godot/project.godot").is_file(),
                          "state": state, "model": MODEL,
                          "paid_api": False, "autopush": False}, ensure_ascii=False, indent=2))
        return 0
    return run_once()


if __name__ == "__main__":
    sys.exit(main())
