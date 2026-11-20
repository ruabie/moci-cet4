# V0.30 clothing trial — pinned Quaternius CC0 assets

- Original author: Quaternius. Official pack: https://quaternius.com/packs/modularcharacteroutfitsfantasy.html, released under **CC0 1.0 Universal**.
- Independent public mirror: `agentkaerf/FreeModels@db3df04d1e4714298a09510b26fb6de6645138a2`. License file `Modular Character Outfits - Fantasy[Standard]/License_Standard.txt`, Git blob `6b19a58ab4a9b2fb9edc6dfeaf11d4e5f58ca03f`.
- Exact **male peasant** modular cloth meshes: `Male_Peasant_Body` (shirt), `Male_Peasant_Legs` (trousers), `Male_Peasant_Feet` (shoes). All 3 glTFs have 65-bone skins. Each .gltf, .bin, BaseColor/Normal/ORM texture is SHA-1 Git-blob pinned in `tools/acquire_outfit_v30.py`.
- This *is not an acceptable modern civilian outfit yet*. It is an **engineering trial to verify compatible full-body skinned clothing** on the proven V0.29 65-joint Quaternius base. Peasant styling, texture resolution, gender diversity, fit, hair, and shoes must pass an independent *visual* gate before any city integration.
- The test runs in isolated GitHub Actions, downloads checked CC0 source only during build. No extra paid services or runtime network. Does not modify production character or the public V0.18 Web export.
