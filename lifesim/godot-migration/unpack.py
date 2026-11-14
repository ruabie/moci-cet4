#!/usr/bin/env python3
"""One-time recovery of a pinned original Godot V0.3 archive into the feature branch."""
from pathlib import Path
from hashlib import sha256
import base64
import io
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / "lifesim/godot-staging"
TARGET = ROOT / "lifesim/godot"
EXPECTED_SHA = "bd96c049a2ff0ff418018d167b347c9b3f06f868c09ab7a5d4280ec35d8f1239"
NAMES = {
    "QA_REPORT.md", "README.md", "scenes/main.tscn", "art/icon.svg",
    ".gitignore", "scripts/city_builder.gd", "scripts/player.gd",
    "scripts/world_clock.gd", "scripts/main.gd", "scripts/game_state.gd",
    "tests/qa_headless.gd", "tests/check_delimiters.py",
    "tests/check_structure.py", "project.godot",
}
chunks = sorted(STAGING.glob("source-*.part"))
if len(chunks) != 7:
    raise SystemExit(f"Expected 7 source parts; found {len(chunks)}")
encoded = "".join(p.read_text(encoding="ascii").strip() for p in chunks)
data = base64.b64decode(encoded, validate=True)
if sha256(data).hexdigest() != EXPECTED_SHA:
    raise SystemExit("Archive checksum mismatch: refusing to extract")
with tarfile.open(fileobj=io.BytesIO(data), mode="r:xz") as tar:
    members = tar.getmembers()
    if set(m.name for m in members) != NAMES:
        raise SystemExit("Unexpected source filenames")
    if sum(m.size for m in members) > 100_000:
        raise SystemExit("Expansion exceeds size limit")
    if any(not m.isfile() or m.issym() or m.islnk() for m in members):
        raise SystemExit("Only regular source files permitted")
    for m in members:
        p = TARGET / m.name
        if not p.resolve().is_relative_to(TARGET.resolve()):
            raise SystemExit("Traversal refused")
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(tar.extractfile(m).read())
print("Restored 14 original Godot project files; engine QA still required.")
