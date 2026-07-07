# retro_journal_proto

Godot 4.x retro first-person prototype in the style of Doom 1-2, Blood, Duke Nukem 3D, Silent Hill 4, and old 2000s online worlds.

Open this folder in Godot:

`C:\GameDev\retro_journal_proto`

Main scene:

`res://scenes/Main.tscn`

Quick run:

`RUN_TEXTURED_PROTOTYPE.bat`

## Current prototype

- WASD movement and mouse look.
- Center dot interaction cursor.
- Main yurt room.
- Interactable cube with fullscreen memory cutscene.
- Memory painting appears after the cube cutscene.
- Door transition to infinite road scene.
- VHS-style return behavior on the road scene.
- Dynamic outdoor sky cloud system with 3 runtime layers: FAR_CLOUDS, MID_CLOUDS, ACCENT_CLOUDS.

## Cloud PNGs Used By The Sky

The cloud system scans `res://assets/textures/sky/clouds_runtime_clean/` and uses every suitable cleaned PNG cloud. Source PNGs stay in `res://assets/textures/sky/`, but runtime rendering uses cleaned files so rectangular checkerboard/cards do not appear.

Currently used cloud PNGs:

- `res://assets/textures/sky/clouds_runtime_clean/cloud_01.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_02.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_03.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_04.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_05.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_06.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_07.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_08.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_09.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_10.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_11.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_12.png`
- `res://assets/textures/sky/clouds_runtime_clean/cloud_13.png`

Cloud setup details:

- `res://scripts/sky_clouds_controller.gd`
- `res://docs/SKY_CLOUDS_SETUP.md`
- `res://docs/SKY_CLOUDS_TRANSPARENCY_FIX.md`

## For Codex

Read `AGENTS.md` first. It contains the current project map, important files, and verification commands.
