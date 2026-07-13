# Lost Signal — отчёт о реализации vertical slice

Дата: 13 июля 2026 года. Engine: Godot 4.7 stable, renderer: OpenGL Compatibility.

## Запуск и последовательность

Старт проекта: `res://scenes/lost_signal/road/NightDrive.tscn`.

Команда пользователя запускает новую последовательность без дополнительного пути сцены:

```powershell
& 'C:\Users\Linux\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe' --path 'C:\GameDev\retro_journal_proto'
```

Flow: `NightDrive → DinerSequence → optional Restroom → DinerSequence post-meal → ForestRoad → RabbitEvent → DemoComplete → Main.tscn`.

После финальной карточки `Main.tscn` загружается автоматически через 6 секунд; `E` продолжает немедленно. `R` запускает slice заново, `Esc` возвращает в Main. Альтернативный launcher: `RUN_LOST_SIGNAL_DEMO.bat`.

## Управление

| Этап | Управление |
|---|---|
| Автомобиль | mouse look; `E` — регистратор; `1/2/3` — FRONT/REAR/SPLIT; `E`/`Esc` — закрыть |
| Закусочная | ограниченный mouse look на автоматическом пути; меню — `1/2/3` или мышь |
| После еды | `F` — туалет; `E` — машина |
| Туалет | `WASD`, mouse look; у раковины `E` — умыться; `F` — в зал |
| Финал | `E` — Main; `R` — заново; `Esc` — Main |

## Архитектура

- `LostSignalFlow` — единственный владелец этапа, заказа и флагов `meal_finished`, `restroom_visited`, `washed_face`, `dashcam_viewed`, `rabbit_event_seen`.
- `LostSignalSceneLoader` — `ResourceLoader.load_threaded_request`, progress overlay, обработка ошибки, два кадра ожидания `_ready()` нового root и transition guard.
- `LostSignalInputLock` — ref-counted владельцы `dashcam`, `blink`, `sink`, `scene_loader`; teardown освобождает lock.
- Legacy `GameState` сохранён отдельно; `Main.tscn`, Player, cube, двери и InfiniteRoad не переписаны.

## Дорога, автомобиль и регистратор

- Автомобиль остаётся у мирового нуля; шесть заранее созданных сегментов по 60 m перемещаются назад и переиспользуются без allocate/free при recycle.
- Asphalt — ambientCG Road012C 2K PBR; небо — Qwantani Night 4K EXR; горизонт неподвижен.
- Салон содержит dashboard, gauges, steering wheel, seats, console, doors, pillars, roof, windshield, mirrors, hood, headlights и крупный dashcam возле зеркала.
- Два feed SubViewport имеют 640×360, отдельные Camera3D и исключают physical screen layer. Вне focus оба `UPDATE_DISABLED`; FRONT/REAR/SPLIT активируют только нужные feeds.
- Физический экран регистратора получает ViewportTexture; fullscreen focus UI показывает REC, mode, timestamp, noise/scanline.

## Закусочная и еда

- Два реальных `Path3D`: парковка/дверь/стойка и стойка/зал/стол. CameraRig перемещается непрерывно, с walk bob и локальным look.
- Четыре роли: анимированный Quaternius cashier, Panda visitor, Rabbit server и отдельный cat visitor fallback. Idle/Sitting/Walk_Holding запускаются с разными offsets.
- Точные реплики сохранены: `Доброй ночи. Что будете заказывать?`, `Спасибо за выбор. Ас болсын.`, `Ваш заказ.`
- Три блюда: Лагман, Котлета с картофелем, Яичница с колбасой. У каждого заранее созданы `Full`, `Partial`, `Empty`.
- Стадии еды меняются только обработчиком `BlinkOverlay.full_dark`. Моргание — две изогнутые маски век, а не прямоугольный fade.
- Добавлены door chime, кассовый one-shot, cutlery one-shot и интерьерный ambience bus.

## Туалет, вода и зеркало

- Отдельная сцена размером 8×6 m: две Quaternius sink, toilets, stalls, urinals, mirror, soap, dryer, bin, utility props, pipes, vent, cabinet, mop, bucket, cleaners, drain и wet-floor sign.
- Умывание: input lock → tween к sink → shader water stream + particles + loop → blink/full_dark → `washed_face=true` → гарантированный stop → camera return.
- Зеркало использует один 512×512 SubViewport; update включён только при нужном расстоянии/угле и всегда выключается при teardown.
- Тела героя нет; mirror camera показывает окружение без пустого «места тела».

## Лес и заяц

- Переиспользуются те же `VehicleInterior`, `LoopingRoad` и `DashcamSystem`.
- Каждый из шести сегментов содержит собственные Kenney MultiMesh variants; нет одного бесконечного AABB. Ближние деревья отделены от дальних и имеют visibility ranges.
- Заяц запускается по дистанции 245 m ровно один раз. Перед ним шевелится трава и звучит rustle; затем CDmir Rabbit проигрывает `Armature|Running` по Path3D со скоростью 9.2 m/s.
- Машина кратко снижает скорость, столкновения/stinger/крови нет; модель скрывается более чем через секунду после выхода.

## Свет, аудио и производительность

- Runtime buses: `Ambience`, `Vehicle`, `InteriorRoom`, `SFX`, `UI`, `Dialogue`; InteriorRoom получает короткий reverb.
- Детерминированные локальные WAV loops/one-shots создаются `tools/generate_lost_signal_audio.py`; BigSoundBank door chime — официальный CC0 OGG.
- Dynamic shadow key lights ограничены одним на сцену. Интерьеры получили BoxOccluder3D; лес использует segment MultiMesh и visibility ranges.

Измерение на RTX 3050, 1920×1080, OpenGL Compatibility:

| Сцена | Draw calls | Rendered objects | Primitives | Lights / shadows | Active SubViewport |
|---|---:|---:|---:|---:|---:|
| NightDrive | 206 | 293 | 5,432 | 6 / 1 | 0 вне focus |
| Diner entry view | 17 | 90 | 2,786 | 15 / 1 | 0 |
| Restroom mirror-facing | 78 | 195 | 7,338 | 3 / 1 | 1, потому что зеркало видно |
| ForestRoad | 203 | 286 | 41,816 | 5 / 1 | 0 вне focus |

Offscreen benchmark после warmup показал 358–651 FPS; movie-writer visual pass дал примерно 8.7–12.0 ms GPU/frame. Это подтверждает запас относительно цели 60 FPS; цифры не заменяют профилирование финальной экспортной сборки.

## Реально выполненные тесты

- QA 1: `lagman meal=true restroom=true washed=true dashcam=true rabbit=true`, exit 0, Output clean.
- QA 2: `cutlet meal=true restroom=false washed=false dashcam=true rabbit=true`, exit 0, Output clean.
- QA 3: `eggs meal=true restroom=false washed=false dashcam=true rabbit=true`, exit 0, Output clean; повторные transition/rabbit calls заблокированы.
- Трёхминутная симуляция road loop: 3,782.1 m, те же шесть instance IDs, nodes stable, spacing 60 m, PASS.
- Threaded финальный переход `ForestRoad → Main.tscn`: PASS; current scene подтверждена как `Main`.
- `Main.tscn`, `InfiniteRoad.tscn`, `UndergroundSteppe.tscn`: exit 0. В Main остаётся существовавшее до задачи предупреждение `pine_sapling_medium`; Lost Signal его не создаёт.
- 109 Sushi glTF, 401 Kenney GLB, Rabbit texture refs и 672 Godot import sidecars проверены; `valid=false=0`.

## Основные созданные/изменённые файлы

- Созданы `scenes/lost_signal/{road,diner,restroom,forest,ui}/` и `scripts/lost_signal/{core,road,diner,restroom,forest,ui,visual,audio}/`.
- Созданы `shaders/lost_signal/`, `assets/lost_signal/`, `RUN_LOST_SIGNAL_DEMO.bat`, QA/benchmark tools и обязательные документы.
- Изменены `project.godot` (autoload, Input Map, start scene), `.gitignore` (scoped runtime unignore), `README.md`, `README_RU.md`.
- `scenes/Main.tscn` и legacy gameplay-файлы не изменялись этой реализацией; существующие пользовательские dirty changes сохранены.

## Исправленные ошибки

- Godot-3 shader mode `depth_draw_alpha_prepass` заменён на Godot-4 `depth_prepass_alpha`.
- Food swap перенесён из конца blink строго в `full_dark`.
- Добавлены cleanup blink/sink/dashcam/audio/SubViewport и защита выгрузки coroutine.
- Исправлена триангуляция изогнутых eyelid polygons на малом closure.
- Устранены headless Dummy-audio ObjectDB leaks.
- Восстановлен отсутствовавший официальный Kenney `Textures/colormap.png`.
- Повторно импортирован полный Qwantani EXR; все `.import` валидны.
- SceneLoader держит lock до `_ready()` новой сцены и откатывает Flow state при load failure.

## Реальные ограничения

- Три рекомендуемых Sketchfab CC BY ассета требуют ручного входа: Generic Sedan interior, dashcam case и Improved Feline Anthro. Текущая сборка проходима на детальном bespoke салоне/регистраторе и fallback-кошке, но это не три primary-модели из research. Точные действия: `docs/MANUAL_DOWNLOADS.md`.
- Реплики представлены точными субтитрами; актёрской озвучки нет. Есть soundscape, chime и SFX.
- Compatibility renderer использует depth fog и geometry wet patches вместо Forward+ volumetric fog/Decal.
- Геометрия сцен собирается детерминированно при `_ready()`, поэтому lightmaps не baked; используются ограниченные dynamic lights, occluders и culling.
- Для публикации 73 MB EXR и model payload желательно хранить через Git LFS. Runtime `assets/lost_signal/**` scoped-unignored, source archives остаются ignored и доступны локально.
