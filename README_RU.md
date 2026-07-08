# Albasty Low-Poly Pack

Пакет для Codex/Blender/Godot: процедурная low-poly модель Албасты и базовая интеграция в игру.

## Что внутри

- `blender_scripts/create_albasty_lowpoly.py` — Blender Python-скрипт, создаёт модель и экспортирует `.glb`.
- `run_generate_albasty.ps1` — запуск генерации из Windows PowerShell.
- `assets/models/` — сюда будет сохранён `albasty_lowpoly.glb`.
- `scripts/albasty_controller.gd` — поведение Албасты в Godot 4.
- `scripts/albasty_spawn_controller.gd` — редкое появление у ЛЭП/спавн-точек.
- `scripts/horse_guard_zone.gd` — зона лошадей, сигнал если Албасты подошла слишком близко.
- `scenes/albasty_instance.tscn` — сцена-обёртка для модели в Godot.
- `docs/CODEX_PROMPT_RU.md` — готовый промт для Codex.
- `config/albasty_model_spec.json` — краткая спецификация существа.

## Быстрый запуск

Из корня проекта:

```powershell
./run_generate_albasty.ps1
```

Или напрямую:

```powershell
blender --background --python blender_scripts/create_albasty_lowpoly.py
```

После успешного запуска должен появиться файл:

```text
assets/models/albasty_lowpoly.glb
```

## Импорт в Godot 4

1. Скопируй папки `assets`, `scripts`, `scenes` в корень Godot-проекта.
2. Открой проект в Godot, дождись импорта `assets/models/albasty_lowpoly.glb`.
3. Открой `scenes/albasty_instance.tscn`.
4. Поставь сцену на уровень или подключи через `albasty_spawn_controller.gd`.

## Масштаб

Скрипт строит модель в метрах. Высота существа около `2.8 м`, origin внизу по центру.

## Визуальная идея

Албасты — высокая сгорбленная степная дух-обманщица: красивое женское лицо почти скрыто чёрными волосами-корнями, руки непропорционально длинные, одежда из крупных треугольных листьев/перьев, золотая диадема, висюльки, амулеты, красные нити, бирюза.

## Ограничение

Это процедурная игровая заготовка, не финальная AAA-модель. Её цель — быстро получить читаемый силуэт в Godot и потом допиливать топологию/анимации.

## Visual Quality Preset / Main.tscn

Forward+ уже включён в `project.godot`: `renderer/rendering_method="forward_plus"`.

Главная сцена использует `res://scripts/visual_quality_preset.gd` на узле `VisualQualityPreset` в `res://scenes/Main.tscn`.

Включены эффекты:

- ACES tonemapping, пониженная экспозиция, умеренный контраст, приглушенная насыщенность.
- Более плотный пыльный fog. Volumetric fog оставлен в пресете, но выключен по умолчанию, потому что может слишком затемнить сцену на части конфигураций.
- SSAO для контактных теней у пола, стен, мебели и объектов.
- Очень мягкий SSIL, если свойство Environment существует в текущей версии Godot.
- Слабый glow с высоким порогом, чтобы светились emissive-объекты, экран ТВ, радио, огонь и лампы, а не вся сцена.
- Мягкие тени DirectionalLight3D и сниженный RoomFillLight, чтобы юрта не выглядела плоско пересвеченной.
- Декоративные визуальные слои без геймплейной логики: пыльные плоскости, мелкий мусор/камни/сухая трава, дальние силуэты, холодно-синяя дымка и тусклые красные акценты.

Если падает FPS, открой узел `VisualQualityPreset` в `Main.tscn` или файл `res://scripts/visual_quality_preset.gd` и отключи тяжелые флаги:

- `low_end = true`;
- `enable_volumetric_fog = false`;
- `enable_ssil = false`;
- `enable_ssao = false`;
- `enable_glow = false`;
- `enable_scene_details = false`, если нужны только базовые постэффекты без дополнительных декоративных мешей.
