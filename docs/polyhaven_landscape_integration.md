# Poly Haven Landscape Integration

## What changed

The existing `SteppeEnvironment` runtime builder now creates a non-flat outdoor landscape around the yurt instead of only a flat `BoxMesh` ground. `Main.tscn` remains the main scene and the yurt, player, sky/clouds, vista cards, powerlines, radio, TV, hatch, UI, and existing interactables stay in their current scene.

The new system is deterministic and safe if external assets are missing. It builds procedural fallback rocks, lonely trees, shrubs, grass, and flowers, then swaps to imported Poly Haven scenes when the downloaded assets are present.

## Added scripts

- `res://scripts/environment/terrain_height_sampler.gd`
- `res://scripts/environment/steppe_terrain_builder.gd`
- `res://scripts/environment/terrain_material_controller.gd`
- `res://scripts/environment/polyhaven_asset_registry.gd`
- `res://scripts/environment/polyhaven_landscape_scatter.gd`
- `res://scripts/environment/polyhaven_multimesh_scatter.gd`
- `res://scripts/environment/ambient_fauna_controller.gd`

## Terrain generation

`TerrainHeightSampler` is the single source for height, normal, and landscape zone. It keeps the yurt center flat, blends relief outward, lowers the left/lake side, adds soft hills and ruts, and marks no-spawn/path/rock/lowland zones.

`SteppeTerrainBuilder` samples that resource into an `ArrayMesh`, adds vertex colors for material masks, generates normals/tangents, and builds a matching `ConcavePolygonShape3D` collision surface so the player does not fall through the new terrain.

## Terrain size and resolution

Tune these exports on `SteppeEnvironment`:

- `terrain_size`: total terrain width/depth in meters.
- `terrain_resolution`: grid resolution. Use `161`, `177`, or `193`; higher costs more triangles.
- `terrain_height_scale`: strength of hills and depressions.
- `yurt_flat_radius`: flat center around the yurt.
- `yurt_blend_radius`: distance where terrain fully blends into relief.
- `full_map_base_enabled`: adds a large old-style safety base under the whole map.
- `full_map_base_size`: width/depth of the safety base.
- `full_map_base_top_y`: top height of the safety base; keep it below the terrain so it catches edges without covering relief.
- `terrain_mesh_collision_enabled`: optional detailed terrain collision. It is off by default because the player uses ground assist for stable movement over the visual terrain.

## Download Poly Haven assets

Balanced download:

```bash
python tools/download_polyhaven_landscape_assets.py --quality balanced
```

Hero download:

```bash
python tools/download_polyhaven_landscape_assets.py --quality hero
```

The very large `pine_sapling_medium` asset is skipped by default. Add `--include-very-heavy` only if you want it locally.

## Process assets with Blender

If Blender is installed:

```bash
blender --background --python tools/process_polyhaven_assets_blender.py
```

This script imports downloaded glTF sources, applies decimation for LOD variants, and exports GLB files into `assets/polyhaven/processed`. If Blender is not installed, the runtime continues to use the downloaded glTF files and procedural fallback assets.

## Heavy assets

Use these `SteppeEnvironment` exports:

- `allow_heavy_hero_assets`: enable/disable hero imported rocks and trees.
- `use_lod_assets`: prefer LOD paths over LOD0.
- `use_multimesh_flora`: use mesh extraction plus MultiMesh for small flora.
- `hero_asset_density_multiplier`: reduce hero rocks/trees.

## Reduce density if FPS drops

Lower these:

- `vegetation_density_multiplier`
- `hero_asset_density_multiplier`
- `terrain_resolution`

Then try disabling:

- `allow_heavy_hero_assets`
- `use_multimesh_flora` only if imported flora meshes are problematic.
- `enable_far_impostors` if a future impostor layer causes issues.

## Zones

- `NO_SPAWN`: yurt interior, entrance, and protected gameplay space.
- `YURT_FLAT`: flat center around the yurt.
- `YURT_EDGE`: sparse plants near the yurt edge.
- `DRY_STEPPE`: default dry grassland.
- `LOWLAND_WET`: lower left/lake side with denser grass.
- `ROCKY_PATCH`: rock-cluster areas and stony ground masks.
- `PATH_EDGE`: readable walking route from the yurt.
- `DISTANT_TREE_PATCH`: far silhouette tree region.
- `SALT_DUST_EDGE`: pale dusty lake-edge ground.

## Add more plants later

Add the asset to `PolyhavenAssetRegistry.ASSETS`, download it into `assets/polyhaven/processed`, then place it from `PolyhavenLandscapeScatter`. Small repeated plants should become MultiMesh instances; avoid hundreds of separate `Node3D` instances.

## Godot workflow

1. Open the project.
2. Let Godot import new assets.
3. Open `Main.tscn`.
4. Run the scene.
5. If import is broken, reimport `assets/polyhaven/processed`.

## Known limitations

- Blender is required for true decimated GLB LOD output.
- The balanced download intentionally skips `island_tree_03`, `searsia_burchellii`, and `pine_sapling_medium`; missing assets fall back procedurally.
- Imported plant materials are tinted through runtime overrides for a muted steppe palette.
- Terrain collision uses a concave shape matching the render mesh; reduce `terrain_resolution` if startup becomes slow.
- `FullMapSafetyBase` is intentionally below the terrain. It prevents falling outside the sculpted terrain area and gives a continuous old-style floor under the whole outdoor map.
- Outdoor walking is stabilized in `player_controller.gd` by sampling `SteppeEnvironment.get_walkable_ground_y()`. This avoids CharacterBody3D snagging on dense concave terrain triangles while keeping the visual landscape unchanged.
