# V0.26 Quaternius Universal Base Characters — compatibility pilot, not shipped

**Why evaluate this instead of more IK patches?** V0.25 confirmed Godot native IK changes rendered pixels but the currently shipped casual character still walks/runs unnaturally. The root cause may be full-body retarget mismatch, not insufficient IK.

- **Original author:** Quaternius.
- **Official base character pack:** https://quaternius.itch.io/universal-base-characters — CC0 1.0 Universal. Official description states compatibility with Universal Animation Library.
- **Original animation pack:** https://quaternius.itch.io/universal-animation-library — CC0 1.0 Universal, already admitted by V0.21 pinned manifest.
- **Exact, existing redistributable CC0 mirror:** `Barbatos6669/elderforge@bb2ce469f0ab2ccfc487faef55550ba07fae2483`, file `assets/characters/base/BaseCharacter.glb`, Git blob `59c4044d5146146170f1c6d5e765985a73bc7875`, size **1,085,752 bytes**. Corresponding Quaternius CC0 license in mirror: `assets/characters/base/LICENSE_Quaternius_CC0.txt`.
- `tools/acquire_base_v26.py` obtains the exact commit **at build time only**, checks Git-blob digest and actual GLB mesh/skin/key bone content and writes SHA256/source record to `tests/v26_base_provenance.json`. No network requests at game runtime; bare checkout does **not** include this binary.
- **Reference UAL asset:** `art/animations/v21/ual1_inplace.glb` is a pinned CC0 skeleton **with original Mannequin mesh and 43 animation clips**. V0.21/V0.25 instead copied rotation-only tracks to the incompatible old modular 49-joint civilian rig; it did not preserve animated pelvis translation.
- V0.26 is a **three-way, review-only** comparison (native UAL Mannequin, matching Universal Base Character, legacy civilian), not a decision to ship a superhero/base suit in a realistic city. Licensing and native match are necessary but **not sufficient** to meet the user's civilian visual target, proper gait, foot contact, or hardware performance.
- Never add restricted animation assets or claim an isolated synthetic/CI screenshot proves actual Windows / Chrome gameplay or final visual acceptance.
