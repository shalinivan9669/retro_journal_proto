Ты работаешь с существующим Godot 4.x проектом:

C:\GameDev\retro_journal_proto

Нужно подключить уже подготовленный asset pack для степи, неба, облаков, цветов и ЛЭП.

Важно:
- НЕ пересоздавай проект.
- НЕ ломай Main.tscn, юрту, куб, cutscene по кубу, дверь, InfiniteRoad и VHS-return.
- Степь должна быть в Main.tscn вокруг юрты.
- Изнутри юрты через выход должно быть видно степь, облака, цветы и ЛЭП вдали.

Файлы уже должны лежать в проекте:

Sky:
- res://assets/textures/sky/sky_mud_road_puresky_1k.exr
- res://assets/textures/sky/sky_mud_road_puresky_1k_tonemap.png
- res://assets/textures/sky/cloud_dark_ash_red_alpha.png
- res://assets/textures/sky/cloud_rose_ash_red_alpha.png

Ground:
- res://assets/textures/ground/tex_steppe_dry_ground_1024.png
- res://assets/textures/ground/tex_steppe_dry_ground_dark_1024.png

Models:
- res://assets/models/flowers/low_poly_flowers_uploaded.glb
- res://assets/models/flowers/flowers_uploaded.glb
- res://assets/models/props/lowpoly_power_pylon_no_wires.glb
- res://assets/models/vegetation_fallback/fallback_grass_patch.glb
- res://assets/models/vegetation_fallback/fallback_flower_red.glb
- res://assets/models/vegetation_fallback/fallback_flower_white.glb
- res://assets/models/vegetation_fallback/fallback_flower_yellow.glb

Script:
- res://scripts/sky_clouds_controller.gd

Задача:

1. Main.tscn должен содержать юрту внутри степи.
2. Добавить физический выход из юрты наружу, не через смену сцены.
3. Добавить степную землю 200x200 м, Y=0, с коллизией.
4. Материал земли: mat_steppe_ground.tres, texture = tex_steppe_dry_ground_1024.png, Repeat enabled.
5. Добавить SkyDome:
   - SphereMesh radius/scale 400–600
   - без коллизии
   - material mat_sky_dome.tres
   - unshaded
   - visible from inside / cull disabled or front cull
   - texture = sky_mud_road_puresky_1k.exr; если EXR не отображается, использовать PNG fallback.
6. Добавить 2 облачных слоя:
   - CloudLayerDarkAshRed с cloud_dark_ash_red_alpha.png
   - CloudLayerRoseAshRed с cloud_rose_ash_red_alpha.png
   - большие PlaneMesh/QuadMesh высоко над картой
   - transparency alpha, unshaded, no collision
   - добавить SkyCloudsController и подключить sky_clouds_controller.gd
7. Добавить WorldEnvironment:
   - слабый fog
   - пепельно-серый fog color
   - мягкий ambient light
8. Добавить PowerPylon:
   - использовать lowpoly_power_pylon_no_wires.glb
   - поставить в 70–120 м от выхода юрты
   - видно из выхода
   - без сложной коллизии, максимум простая BoxShape у основания
9. Расставить цветы и траву:
   - не сеткой
   - пятнами
   - у выхода плотнее
   - по направлению к ЛЭП редкие группы
   - у ЛЭП почти пусто
   - белые чаще, красные реже, жёлтые только одиночные
   - можно использовать загруженные flower packs или fallback-модели
10. Проверить, что из шанырака видно sky dome и облака.

Acceptance criteria:
- Проект запускается.
- Игрок стартует внутри юрты.
- Через выход видно степь и небо.
- Можно физически выйти наружу.
- Земля имеет коллизию.
- SkyDome виден через шанырак и снаружи.
- Облака медленно плывут.
- ЛЭП видна вдали.
- Цветы не выглядят как равномерная сетка.
- Куб, дверь, cutscene, InfiniteRoad и VHS не сломаны.

После выполнения дай:
- список изменённых файлов;
- где менять скорость облаков;
- где менять позицию ЛЭП;
- где менять плотность цветов;
- точную команду запуска.
