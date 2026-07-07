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
