# Open-source notes

This pack is self-contained. No third-party shader code was copied into the project.

The implementation is built from scratch around Godot-native systems:

- `CanvasLayer` + `ColorRect` screen shaders for postprocess overlays;
- `GPUParticles3D` + `ParticleProcessMaterial` for local particle fields;
- `ShaderMaterial` / spatial shaders for corrosion overlays;
- runtime node scanning and group-based attachment in GDScript.

Useful public references for future expansion:

- Godot documentation: 3D particles / GPUParticles3D;
- Godot documentation: screen-reading shaders via `hint_screen_texture`;
- Godot Shaders community library for inspiration only;
- GDQuest Godot 4 VFX demo assets for learning scene organization.

Do not paste random internet shaders into production without checking license and Godot version compatibility.
