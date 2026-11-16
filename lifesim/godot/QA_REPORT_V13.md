# V0.13 Art Direction — Gated Evidence

Goal: replace overscaled, mostly empty V0.12 cafe with curated *kissaten* cafe.

## Changes
- Scale: cafe 9.4 × 8.8 m (82.7 sqm) vs V0.12 11.8 × 12.2 m (144.0 sqm); central 2.1 m approach.
- Lighting: four warm practicals plus a cool glazed-entry fill.
- Materials: deterministic 4 surface-color textures and 4 normal maps with roughness.
- Furniture: curated 15 CC0 Quaternius GLBs, plus retained Kenney food/coffee equipment.
- Composition: fixed bar and pastry displays, banquette, tables, art panels, planted entrance.
- All other gameplay, economics and save format unchanged.

## Important acceptance criteria
- Import and run under Godot 4.7.2 in CI.
- Verify same-camera screenshot, a service angle and an entry/glazing angle.
- Verify gameplay save, purchases and interaction regression tests.
- Browser load and action E/W/Q should be verified separately before claiming a public playable release.
- Subjective art-review may remain FAIL even when all tests are green.
- Cafe remains an instanced interior and is **not yet seamless street-to-interior traversal**.
- No Windows RTX3060 performance result is yet available.