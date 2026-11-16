#!/usr/bin/env python3
"""Rebuild upper-storey GLB from this project's original V0.9 model.

V0.14 uses a separately built walkable ground floor. Removing triangles under
3.68 m prevents the old baked storefront and furniture appearing inside it.
"""
from pathlib import Path
import trimesh
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/architecture/v09_coffee_integrated.glb"
TARGET = ROOT / "art/architecture/v14_cafe_upper_only.glb"
CUTOFF = 3.68

def main():
    scene = trimesh.load(SOURCE, force="scene")
    if not isinstance(scene, trimesh.Scene):
        raise RuntimeError("Expected a scene GLB")
    out = trimesh.Scene()
    count = 0
    for node in scene.graph.nodes_geometry:
        matrix, geom_name = scene.graph[node]
        geom = scene.geometry[geom_name]
        if not isinstance(geom, trimesh.Trimesh):
            continue
        world = trimesh.transform_points(geom.vertices, matrix)
        keep = np.all(world[geom.faces][:,:,1] >= CUTOFF, axis=1)
        if not np.any(keep):
            continue
        part = geom.copy()
        part.update_faces(keep)
        part.remove_unreferenced_vertices()
        out.add_geometry(part, geom_name=geom_name, node_name=node, transform=matrix)
        count += len(part.faces)
    if count < 500:
        raise RuntimeError("Upper building geometry missing")
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    TARGET.write_bytes(out.export(file_type="glb"))
    checked = trimesh.load(TARGET, force="scene")
    if checked.bounds[0][1] < CUTOFF - 0.01:
        raise RuntimeError("Ground floor was not removed")
    print("V14 UPPER PASS:", count, "triangles", TARGET.stat().st_size, "bytes")

if __name__ == "__main__":
    main()
