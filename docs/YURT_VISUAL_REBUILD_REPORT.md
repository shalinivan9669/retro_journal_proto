# Yurt visual rebuild report

## Audit

- The active visual floor is `YurtFloorRich`; the imported `CleanYurt/world/YurtOctagonFloor` remains visually hidden while its separate simple collision remains intact.
- `YurtFloorGenerator.gd` currently generates the base felt, main ornamental rug, and two borders only. The former `Perimeter_Mats` / `Seat_Mat_01..11` ring is no longer generated, so there are no hidden mat meshes or materials to retain.
- The active signal group is repositioned at runtime by `YurtInteriorDressingBuilder` to the north-west wall: TV and radio sit on its generated media table; the old `SignalCenterStand` is hidden.
- The bed, screen, low table, hatch, TV, radio, carpet interaction, and their gameplay scripts remain present.
- `YurtVisualDirector` is the runtime authority that overwrote the much brighter scene light values. Both source scene values and director defaults have now been aligned.
- `yurt_window_vision.gd` previously replaced every `YurtWall_*` surface with the cutout shader and disabled all their shadows.

## Implemented composition

- Signal zone: one horizontal 5.20 x 3.35 m textured wall rug at `(-8.00, 2.30, 7.05)`, Y rotation `131 degrees`, close to the scaled yurt wall behind the existing TV/radio/media-table group, with one restrained dark wooden suspension rail. Its material is double-sided so the imported texture remains visible regardless of triangle winding.
- Quiet center: existing main rug, offset low table and concealed hatch retained; no perimeter mat ring is generated.
- Entrance: a separate 2.40 x 4.80 m Kazakh rug made from the user-provided image is placed flat at `(0, 0.105, -6.65)` directly before the interior exit and rotated 180 degrees, with no collision and its original 1:2 texture proportion preserved.
- The complete `YurtFloorRich` visual root is raised to Y `0.08`, above the terrain plane, eliminating terrain bleed-through while leaving the floor collision at its established walkable height.
- Human memory zone: existing bed, screen, bed interaction and restrained household dressing retained.
- The five triangular `WafflePiqueWallFlag` meshes visible from the entrance are disabled by default.
- Lighting: muted red-grey directional key, low ambient and short low-energy room fill; device lighting remains local and signal glow is nearly off by default.
- Atmosphere detail generation remains disabled in `Main.tscn`, so rectangular dust/haze sheets are not created.
- Exterior clouds, sky controller, mountains, Balkhash backdrop, and steppe builder are untouched.
