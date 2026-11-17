# V0.21 — Quaternius Universal Animation Library 1, build-time CC0 pilot

- **Original creator and license:** Quaternius, **CC0 1.0 Universal**, https://quaternius.itch.io/universal-animation-library and https://quaternius.com/packs/universalanimationlibrary.html.
- **Exact redistributable mirror:** Barbatos6669/elderforge, commit `bb2ce469f0ab2ccfc487faef55550ba07fae2483`, `assets/animations/universal_animation_library_1/UAL1_Standard.glb`, git blob `473e59080288428d0b6da826ba19324d07b191f0`, 7,618,436 bytes.
- **Mirror license:** `assets/animations/universal_animation_library_1/LICENSE_Quaternius_CC0.txt` at that exact commit, text explicitly CC0-1.0.
- This is **in-place/non-root-motion** variant. Preserve game physics translation; motion clips must not teleport game player or alter salary/save rules.
- `tools/acquire_ual_v21.py` downloads this specific immutable GLB **during build**, validates content-addressed git blob and parses real clip/skin metadata before use. No runtime internet requirement. Built source archive should include GLB.
- The UAL animation rig and the V0.18 modular Quaternius character models are both by Quaternius; **same supplier does not prove identical BoneRest transforms, scene hierarchy or animation-path compatibility**. V0.21 must test before gameplay integration.
- Bone names and raw clip count are written to `tests/v21_ual_manifest.json` by CI. The source GLB is not checked into this development branch; do not claim a bare checkout starts offline without running the build-time acquisition step.
- **No claim of motion or visual acceptance** until actual Godot render, animation track path validity, foot-contact evaluation, Chrome input and Windows RTX3060 tests.
- Don't reuse Mixamo or any restricted-content animations without explicit license/redistribution proof. This file is a CC0 pilot, not a blanket license for others' work.
