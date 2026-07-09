Базовый 3D-пакет по сцене: девушка в нише, красная ткань, черная вуаль, отдельное золото/серебро/камни, ковры, масляная лампа, чай каркаде, трубка на фоне.

Файлы:
1. folklore_kazakh_seated_woman_cloth_blockout.glb
   Статичная базовая 3D-модель. Можно открыть в Blender/Godot сразу.

2. create_folklore_scene_basic.py
   Скрипт генерации GLB через Python/trimesh. Нужен, если Codex будет менять геометрию процедурно.

3. blender_add_real_cloth.py
   Скрипт для Blender. Он импортирует GLB, находит объекты с именем cloth_*, добавляет Cloth modifier, pin-группы, collision, толщину ткани, масляную лампу как единственный источник света, камеру и сохраняет .blend.

Главное ограничение:
GLB сам по себе НЕ хранит живую физическую симуляцию ткани. В GLB ткань — это уже сетка/материал. Реальная ткань делается в Blender через Cloth modifier, потом ее можно запечь и экспортировать обратно в GLB для Godot.

Как запустить в Blender:
1. Распакуй архив.
2. Открой Blender.
3. Scripting > Open > blender_add_real_cloth.py > Run Script.
4. Получишь файл folklore_kazakh_seated_woman_REAL_CLOTH.blend рядом с GLB.
5. В Blender нажми Play/прогони таймлайн до 90 кадра, ткань осядет.
6. При необходимости: Object > Apply > Visual Geometry to Mesh, затем экспортируй в GLB для Godot.

Для Godot:
- Импортируй folklore_kazakh_seated_woman_cloth_blockout.glb как обычную сцену.
- Материалы уже названы: gold/silver/ruby/emerald/fabric/veil/glass/lamp.
- Масляная лампа в GLB обозначена объектом visible_oil_lamp_flame_only_light_source. В Godot добавь OmniLight3D прямо в эту точку, теплый цвет, низкая энергия, тени включить.
