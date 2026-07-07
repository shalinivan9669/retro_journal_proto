# Реализация богатого пола юрты

## Где лежит сцена

Основная reusable-сцена:

`res://scenes/yurt/YurtFloorRich.tscn`

Демо для быстрого просмотра:

`res://scenes/yurt/YurtFloorDemo.tscn`

В основной комнате `res://scenes/Main.tscn` сцена уже добавлена отдельным визуальным инстансом `YurtFloorRich`. Старый визуальный меш `CleanYurt/world/YurtOctagonFloor` скрыт, чтобы он не закрывал богатый текстильный пол. Коллизии у нового пола нет: игрок продолжает ходить по прежней простой коллизии `YurtCollision/YurtFloorCollision`.

## Как устроен пол

`YurtFloorRich.tscn` использует `res://scripts/yurt/YurtFloorGenerator.gd`. Скрипт генерирует слои при запуске и в редакторе:

- `Floor_Base_Felt` - большой слегка неровный войлочный диск.
- `Main_Rug_Ornamental` - главный овальный орнаментальный ковер.
- `Main_Rug_Border_Outer` - темный внешний бордюр.
- `Main_Rug_Border_Inner` - внутреннее декоративное кольцо.
- `Center_Medallion_RedFelt` - красный войлочный медальон.
- `Perimeter_Mats/Seat_Mat_01..11` - разные маты вдоль стен.
- `Small_Fabric_Accents` - сложенные ткани и малые акцентные коврики.

Меши не являются простыми квадратами: диск и кольца имеют irregular edge, прямоугольные маты имеют слегка деформированные края, а вершины получают слабые микроволны по Y. Высоты слоев разнесены от `0.000` до `0.024+`, чтобы избежать z-fighting.

## Материалы

Материалы лежат в:

`res://materials/yurt_floor/`

Используются:

- `mat_yurt_base_felt.tres` - базовый теплый серо-бежевый войлок.
- `mat_yurt_main_ornamental_red_cream.tres` - главный красно-молочный орнамент.
- `mat_yurt_ornamental_border_dark.tres` - темный декоративный бордюр.
- `mat_yurt_center_red_felt.tres` - красный войлочный медальон.
- `mat_yurt_checkered_muted.tres` - приглушенная клетка только для акцентов.
- `mat_yurt_fabric_burgundy.tres` - перекрашенная бордовая ткань.
- `mat_yurt_fabric_warm_beige.tres` - перекрашенная теплая бежевая ткань.

Все материалы - `StandardMaterial3D`, `metallic = 0`, roughness высокий, specular низкий. Текстуры настроены на repeat, а разные mesh-элементы получают разные UV scale/rotation через генератор.

## Главные текстуры

Пакет распакован в:

`res://assets/yurt_floor_texture_pack/`

Основные albedo:

- `textures/C_felt_pile/derived/felt_warm_gray_albedo.png`
- `textures/C_felt_pile/derived/felt_deep_red_albedo.png`
- `textures/B_ornamental_pattern/derived/ornament_red_cream_albedo.png`
- `textures/B_ornamental_pattern/derived/ornament_charcoal_cream_albedo.png`
- `textures/D_checkered/derived/checkered_muted_red_cream_albedo.png`
- `textures/A_blue_fabric/derived/fabric_burgundy_albedo.png`
- `textures/A_blue_fabric/derived/fabric_warm_beige_albedo.png`

Roughness/detail-карты подключены только там, где роль карты понятна по имени:

- `textures/C_felt_pile/soft_roughness_or_ao.png`
- `textures/C_felt_pile/pile_height_or_detail.png`
- `textures/D_checkered/checkered_detail_or_roughness.jpg`
- `textures/A_blue_fabric/roughness_or_ao_preview.jpg`

## EXR и raw sources

EXR-карты из архива не подключены к материалам. При headless import Godot 4.7 выдал `Unknown compression type` для EXR, поэтому они сохранены, но вынесены из сканируемой зоны в:

`res://assets/yurt_floor_texture_pack/raw_sources_ignored/`

Туда же вынесен исходный `gray_felt_basecolor.jpg`, который тоже не импортировался чисто. Вместо него используется стабильный derived PNG `felt_warm_gray_albedo.png`.

Источник Blender `fabric_pattern_07_1k.blend` сохранен в:

`res://assets/yurt_floor_texture_pack/source_blend_ignored/`

Это сделано, чтобы Godot headless не требовал настроенный Blender при проверке проекта.

## Как менять размер пола

Открой `YurtFloorRich.tscn` или инстанс `YurtFloorRich` в `Main.tscn` и меняй exported-поля на корневом узле:

- `floor_radius` - общий радиус композиции.
- `mat_count` - число периметрических матов.
- `random_seed` - другая, но стабильная раскладка неровностей.
- `edge_irregularity` - сила неровных краев.
- `wave_strength` - микроволны по поверхности.

Для текущей юрты в `Main.tscn` радиус выставлен `9.35`, чтобы базовый войлок заходил под стены и полностью перекрывал степную плоскость внутри юрты.

Материалы пола используют `cull_mode = 2`, потому что процедурные ковровые плоскости тонкие и должны быть видимы с first-person камеры независимо от winding стороны треугольника.

## Как встроить в другую юрту

Инстансни `res://scenes/yurt/YurtFloorRich.tscn` в сцену юрты как визуальный `Node3D` без коллизии. Размести его немного выше базового пола, например `Y = 0.01..0.02`, если под ним уже есть плоская геометрия. Коллизию игрока оставь простой и плоской.
