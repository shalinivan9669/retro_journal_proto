# Godot Steppe + Sky Complete Asset Pack

Скопируй папку `assets/` и `scripts/` в корень проекта:

`C:\GameDev\retro_journal_proto\`

После копирования в Godot пути будут такими:

## Sky / Clouds
- `res://assets/textures/sky/sky_mud_road_puresky_1k.exr` — основная HDRI/EXR текстура неба.
- `res://assets/textures/sky/sky_mud_road_puresky_1k_tonemap.png` — PNG fallback/preview, если EXR неудобно быстро тестить.
- `res://assets/textures/sky/cloud_dark_ash_red_alpha.png` — тёмное пепельно-красное облако с альфой.
- `res://assets/textures/sky/cloud_rose_ash_red_alpha.png` — розово-пепельное облако с альфой.

## Ground
- `res://assets/textures/ground/tex_steppe_dry_ground_1024.png` — сухая степная земля.
- `res://assets/textures/ground/tex_steppe_dry_ground_dark_1024.png` — более тёмная версия.
- `res://assets/textures/ground/tex_steppe_detail_mask_1024.png` — маска/шум для вариации.

## Models
- `res://assets/models/flowers/low_poly_flowers_uploaded.glb` — твой загруженный цветочный пак.
- `res://assets/models/flowers/flowers_uploaded.glb` — второй загруженный цветочный пак.
- `res://assets/models/props/lowpoly_power_pylon_no_wires.glb` — простая ЛЭП без проводов.
- `res://assets/models/vegetation_fallback/fallback_grass_patch.glb` — запасная трава.
- `res://assets/models/vegetation_fallback/fallback_flower_red.glb` — запасной красный цветок.
- `res://assets/models/vegetation_fallback/fallback_flower_white.glb` — запасной белый цветок.
- `res://assets/models/vegetation_fallback/fallback_flower_yellow.glb` — запасной жёлтый цветок.

## Script
- `res://scripts/sky_clouds_controller.gd` — простой контроллер движения облачных слоёв.

## Как использовать небо
1. Создай `SkyDome` как огромный SphereMesh вокруг сцены, без коллизии.
2. Материал: unshaded, видимый изнутри, texture = `sky_mud_road_puresky_1k.exr`.
3. Добавь 2 больших PlaneMesh/QuadMesh слоя высоко в небе:
   - `CloudLayerDarkAshRed` с `cloud_dark_ash_red_alpha.png`.
   - `CloudLayerRoseAshRed` с `cloud_rose_ash_red_alpha.png`.
4. Материал облаков: unshaded + transparency alpha + cull disabled.
5. На Main.tscn добавь `SkyCloudsController` со скриптом `sky_clouds_controller.gd`.

## Важно
- SkyDome и CloudLayer не должны иметь коллизии.
- Цветы размещать пятнами, не сеткой.
- ЛЭП ставить в 70–120 метрах от выхода юрты.
- Туман нужен, чтобы скрыть край карты.
