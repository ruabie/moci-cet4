# APDS Free V0.1 — zero-new-spend pilot

This is a **local-only candidate coordinator**, not a completed autonomous development service. It uses Python's standard library and, when a Godot source file exists, a local Ollama model. It never calls a paid API.

## Honest current state
- Only the LifeSim Godot subtree is eligible; WordRide, CET-4 and Kotoba are excluded.
- \`tasks.json\` starts with a **source-exists gate**, not a fabricated development task.
- Missing \`lifesim/godot/project.godot\` => \`waiting_for_source\`.
- An edit task (added after real source is connected) sends **one existing .gd file** to Ollama at **127.0.0.1 only** and allows at most two constrained attempts.
- Successful output is saved in \`.local/proposals/\` as an **unverified candidate**. It does **not** overwrite source, execute model-generated code, push Git, merge a PR, publish software or claim the game works.
- GitHub CI only tests the coordinator with deterministic fakes; a green check is **not evidence** that Ollama, Godot or the actual game runs.

## Windows first-run (only on your own computer)
1. Install free Python 3.11+ and [Ollama](https://ollama.com/download) through their official distributors. Neither is remotely installed by this PR.
2. In PowerShell at the Git clone root, run:
   \`ollama pull qwen2.5-coder:3b\` (one-time model download, disk and network usage).
3. Check source and persisted state: \`python apds-free/runner.py --status\`.
4. Run one bounded unit: \`python apds-free/runner.py --once\`.
5. Tests: \`python -m unittest discover -s apds-free/tests -v\`.

The pilot does not automatically register a Windows Scheduled Task. Only do that after confirming the on-device model works, code/source permissions are appropriate, and the task is isolated. If the computer is off, local inference is stopped.

## Adding an edit task
After the actual Godot project is committed and verified, append:
\`\`\`json
{"id":"G1-a","kind":"edit","path":"lifesim/godot/scripts/player.gd","goal":"Fix a specific reproducible issue","enabled":true}
\`\`\`
Only use a **real, existing** path; never create a fake empty source to satisfy the gate. AI candidates are review-pending until independent Godot runtime and GitHub CI tests are added.

## Safety and budget
- Hardcoded loopback Ollama endpoint; never configurable to a remote paid service.
- No model-authored shell commands; model proposals are exact-search replacements on existing .gd content.
- Attempts capped at 2, source-size bounded, checks for symlink/path escapes, file type and uniqueness.
- Source is not modified. State persists in \`.local/state.json\` and proposed content remains untracked by Git.
- A stale lock causes a safe stop. Resolve a stale lock only after verifying no runner process is active.
- This repository is public; do not commit private code, passwords, proprietary assets, or model logs.

### Next acceptance gates
1. Recover real Godot V0.3 source into a **separate draft PR** (tracked at issue #12).
2. Test Ollama locally on the target laptop, record model and hardware evidence.
3. Add isolated Godot headless CI, safe candidate-to-draft-PR promotion and CI feedback polling.
4. Demonstrate real failure -> patch -> CI -> bounded retry -> reviewable release candidate.
5. Only then consider unattended scheduling. No automatic main-branch merge and no paid service.
