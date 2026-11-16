# V0.18 licensed humanoid art: Quaternius (CC0-1.0)
Seven skinned GLB characters copied byte-for-byte from the Quaternius Ultimate
Modular Men / Ultimate Modular Women art in the immutable open-source showcase:
https://github.com/trebeljahr/quaternius-showcase/tree/0128ca510d653bb04d6d1e4885bd8890b5050b4f/public/glb

License record: https://github.com/trebeljahr/quaternius-showcase/blob/0128ca510d653bb04d6d1e4885bd8890b5050b4f/LICENSES.md
Upstream author: Quaternius, https://quaternius.com/
The showcase's MIT code is NOT copied; only explicitly CC0 original humanoid assets.

player_casual.glb = modular_men/Casual2.glb
casual_male.glb = modular_men/Casual.glb
worker_male.glb = modular_men/Worker.glb
suit_male.glb = modular_men/Suit.glb
casual_female.glb = modular_women/Casual.glb
formal_female.glb = modular_women/Formal.glb
worker_female.glb = modular_women/Worker.glb

Exact upstream Git blob SHAs pinned in tests/check_characters_v18.py.
Models have humanoid skinning but no integrated movement clips. Walking currently
uses the project's procedural bone motion via remapping, NOT a professional mocap
or fully retargeted animation library. This is a controlled prototype art pass.
