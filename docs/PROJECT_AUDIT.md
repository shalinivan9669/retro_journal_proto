# PROJECT AUDIT — Lost Signal vertical slice

> Финальная интеграция после аудита: по прямому запросу пользователя от 13 июля 2026 года `run/main_scene` переключён на `res://scenes/lost_signal/road/NightDrive.tscn`. После завершения vertical slice прежняя `res://scenes/Main.tscn` загружается автоматически. Сама legacy-сцена не переписывалась и прошла регрессионный headless-запуск.

Дата аудита: 13 июля 2026  
Проект: `C:\GameDev\retro_journal_proto`  
Движок: Godot `4.7.stable.official.5b4e0cb0f`  
Git: ветка `main`, ревизия `3f058fa` на момент проверки

## 1. Итог аудита

Lost Signal следует внедрять как изолированный набор сцен в пространстве имён `res://scenes/lost_signal/` и `res://scripts/lost_signal/`, сохраняя существующую юрту, `Main.tscn`, `InfiniteRoad.tscn`, подземный уровень, куб, TV/radio-сигналы и VHS-возврат.

В проекте уже есть полезные рабочие основы:

- стабильный first-person `Player` с WASD, мышью, центральной точкой и ray-based взаимодействием;
- модальное диалоговое окно, выборы, интерактивные подсказки и блокировка игрока;
- один существующий Autoload `GameState`;
- несколько рабочих переходов между сценами;
- полноэкранные CanvasLayer-эффекты и проверенная механика VHS;
- генераторы окружения, реестр Poly Haven-ассетов и chunked MultiMesh;
- большая локальная библиотека CC0 Poly Haven растительности, камней, материалов и props.

Но готовой архитектуры Lost Signal до начала текущей интеграции не было:

- нет общего асинхронного загрузчика сцен;
- нет общего ref-counted InputLock;
- нет GameFlow/state machine для прохождения;
- нет timed subtitle controller;
- нет аудиошин кроме неявного `Master`;
- нет подходящего автомобиля, закусочной, сантехники, антропоморфных NPC и анимированного зайца;
- существующий `InfiniteRoad` — пешая сюрреалистическая сцена с UV-scroll и VHS, а не автомобильная система из шести циклических сегментов.

В рабочем дереве уже появились незакоммиченные Lost Signal core/road/UI-заготовки. Они являются текущей незавершённой интеграцией, а не доказательством готовности. В частности, процедурный автомобиль, деревья и антропоморфные персонажи из примитивов допустимы только как инженерный scaffolding для проверки flow. Они прямо не проходят финальные критерии ТЗ и должны быть заменены выбранными лицензированными моделями.

## 2. Проверка приложенного архива и инструкций

Проверен исходный архив:

`C:\Users\Linux\Downloads\Lost_Signal_Codex_Scene_Pack.zip`

В ZIP 33 записи: 11 директорий и 22 файла. Распакованная копия в `.codex_scene_pack/` совпадает с архивом по именам и размерам; пропущенных файлов нет. Все 22 файла прочитаны полностью в UTF-8:

- `Pasted text(1).txt` — 1476 строк;
- `lost_signal_scene_pack/README_RU.md` — 40 строк;
- `lost_signal_scene_pack/CODEX_MASTER_PROMPT.md` — 171 строка;
- `docs/ASSET_MANIFEST.md` — 131 строка;
- `docs/SCENE_BLUEPRINT.md` — 343 строки;
- `docs/IMPLEMENTATION_CHECKLIST.md` — 114 строк;
- `docs/ASSET_CREDITS_TEMPLATE.md` — 34 строки;
- `tools/asset_manifest.json` — 89 строк;
- 11 GDScript-примеров из `scripts/` — 879 строк суммарно;
- 2 shader-примера из `shaders/` — 52 строки суммарно.

Также полностью проверены обе отдельные инструкции из вложений задачи:

- `attachments/10d1371c-.../pasted-text.txt` — 1007 строк;
- `attachments/671f8385-.../pasted-text.txt` — 853 строки.

Инженерный вывод по пакету:

- `SCENE_BLUEPRINT.md` и исходное ТЗ задают обязательное содержание, тайминг и критерии качества;
- GDScript-файлы — архитектурные шаблоны, не drop-in реализация;
- шаблонный `DashcamController` нельзя подключать глобально без зоны доступности: в исходном виде он ловит `interact` в любой точке сцены;
- шаблонные `GameFlow`, `SceneLoader`, `InputLock` нужно адаптировать к существующему `GameState`, текущему `Player` и UI;
- два пакетных шейдера совместимы с выбранным Compatibility renderer, но требуют реальных материалов, текстур и scene wiring;
- манифест требует 10 основных внешних ассетов; Sketchfab-позиции, вероятно, потребуют ручной авторизованной загрузки.

## 3. Фактическая конфигурация проекта

### Project settings

| Параметр | Фактическое значение | Значение для Lost Signal |
|---|---|---|
| Godot | 4.7 stable | API шаблонов проверять именно на 4.7 |
| Main scene | `res://scenes/Main.tscn` | Не ломать; финальный entry Lost Signal переключать только после полной проверки |
| Renderer | `gl_compatibility` | Не рассчитывать на Forward+-only эффекты |
| Viewport | 1920×1080 | Целевой профиль ТЗ |
| Window mode | fullscreen, borderless | Полноэкранные CanvasLayer сохранять |
| 3D scale | `0.9` | Учитывать при оценке GPU и SubViewport |
| MSAA/TAA/FXAA | выключены | Геометрия/тонкие линии могут мерцать; не маскировать это сверхтяжёлыми материалами |
| Debanding | включён | Полезно для ночных градиентов |
| Anisotropy | 4 | Дорога потребует читаемой разметки под острым углом |

Compatibility renderer — существенное ограничение. Volumetric fog, SDFGI, SSR и ряд продвинутых post effects нельзя считать доступной основой. Для ночи следует использовать обычный Environment fog, туман-карты/меши, baked/mixed lighting, reflection probes при необходимости и ограниченное число динамических SpotLight3D. Смена renderer на Forward+ без отдельного регрессионного прогона запрещена: это может изменить весь текущий визуал юрты и старых сцен.

### Autoload

До текущей интеграции существовал только:

- `GameState="*res://scripts/game_state.gd"`.

`GameState` сейчас хранит только состояние ритуала Albasty и временный cooldown. Полноценного save/load нет; состояние живёт только в процессе игры.

В незакоммиченном рабочем дереве уже добавлены в правильном порядке:

1. `LostSignalInputLock`;
2. `LostSignalSceneLoader`;
3. `LostSignalFlow`.

Это допустимо как namespaced подсистема vertical slice: существующего `GameFlow` или `SceneLoader` раньше не было. При этом запрещено добавлять ещё одну параллельную тройку менеджеров. `LostSignalFlow` должен быть единственным владельцем progression state Lost Signal, а `GameState` остаётся владельцем legacy-состояния. Если флаги Lost Signal понадобятся вне этого slice или в сохранениях, их нужно перенести/проксировать в `GameState`, а не дублировать.

### Input Map

В исходном `project.godot` раздела `[input]` не было. Существующий игрок использует прямую проверку клавиш для WASD, Shift, Ctrl/C, F, `2`, F11 и Esc. Только `interact` создавался runtime в `player_controller.gd` и включал:

- `E`;
- левую кнопку мыши.

В текущем незакоммиченном `project.godot` появились:

- `interact` — E;
- `restroom` — F;
- `menu_option_1/2/3` — 1/2/3;
- `cancel` — Esc.

Нужно учитывать побочный эффект: как только `interact` заранее существует в Project Settings, `_ensure_input_actions()` в legacy `Player` выходит раньше и больше не добавляет левую кнопку мыши. Критический контракт AGENTS — E через центральную точку — сохраняется, но старое взаимодействие ЛКМ меняет поведение. Это изменение следует либо принять явно, либо исправить `_ensure_input_actions()` так, чтобы он добавлял только отсутствующие события, не создавая дубликаты.

Не хватает формальных actions для ограниченного движения в туалете (`move_forward/back/left/right`). Legacy WASD всё равно работает через прямые клавиши, но новый код не должен смешивать два способа без ясной причины. `continue` не нужен как отдельное action: это семантически тот же E/interact.

Конфликты управления:

- F в legacy `Player` подтверждает TV/radio-сигнал, а в Lost Signal означает туалет/возврат;
- `2` в legacy `Player` включает лопату, а в dashcam выбирает REAR;
- E закрывает существующие диалоги до вызова взаимодействия.

Поэтому автомобиль, diner и forest не должны инстанцировать legacy `Player`. Для Restroom можно переиспользовать его только через отдельный режим/адаптер, отключающий shovel, signal trigger, sprint/crouch lore и landscape ground assist.

## 4. Инвентаризация проекта

Без `.godot`, `.git` и распакованного пакета найдено:

- 79 GDScript-файлов;
- 49 сцен `.tscn`;
- 23 shader-файла по всему проекту, из них 16 находятся в основном каталоге `shaders/`;
- 89 ресурсов `.tres`;
- 13 WAV, 4 OGG и 6 OGV;
- большая библиотека локальных внешних assets.

Общий объём корня на машине — около 6.11 GiB. Каталог `assets/` уже тяжёлый:

| Раздел | Размер |
|---|---:|
| `assets/textures` | ~1091.7 MiB |
| `assets/polyhaven` | ~865.3 MiB |
| `assets/backdrops` | ~165.6 MiB |
| `assets/characters` | ~66.6 MiB |
| `assets/yurt_floor_texture_pack` | ~66.5 MiB |
| `assets/videos` | ~26 MiB |
| `assets/models` | ~21.5 MiB |
| `assets/audio` | ~2.2 MiB |

Критический пример: `assets/textures/sky/overcast_soil_puresky_16k.exr` занимает ~984 MiB, импортируется без mipmaps и без size limit и используется `materials/mat_sky_dome.tres`. Его нельзя переиспользовать как runtime-небо Lost Signal. Требуется оптимизированный Qwantani 4K/8K или процедурное звёздное небо; исходник высокого разрешения должен оставаться source-only.

`.gitignore` намеренно игнорирует практически все изображения и 3D-модели. Это означает, что новая сцена может работать локально и быть невоспроизводимой после clone. До handoff нужен один из двух явных вариантов:

1. скорректировать policy Git/LFS для runtime-ассетов; или
2. сохранить надёжный downloader/import manifest и документировать внешнее размещение.

Лицензии и исходные URL всё равно должны быть tracked в `ASSET_CREDITS.md` и рядом с source archives.

## 5. Существующие системы и решение по переиспользованию

| Система | Где находится | Фактическое поведение | Решение |
|---|---|---|---|
| Legacy state | `scripts/game_state.gd` | Только Albasty ritual/cooldown | Сохранить; не смешивать случайно с flow сцен |
| First-person | `scenes/player/Player.tscn`, `scripts/player_controller.gd` | WASD, sprint, crouch, mouse look, shovel, landscape assist | Сохранить legacy; использовать только Restroom mode/adapter |
| Interaction | `player_controller.gd`, `interactable.gd` | RayCast 4.5 m, Area/Body, поиск parent method, E/ЛКМ | Переиспользовать method contract `interact()` и prompt pattern |
| Center dot | `AimDotUI` | 6×6 Panel по центру | Сохранить как визуальный язык; Lost Signal HUD уже делает 4×4 dot |
| Dialogue | `DialogueUI.tscn`, `dialogue_ui.gd` | Message, choice buttons, prompt, modal player lock | Не копировать как subtitle manager; переиспользовать идеи и при необходимости общий интерфейс |
| Signal dialogue | `SignalDialogueWindow` | Отдельное полумодальное окно | Не использовать в Lost Signal |
| Cutscene lock | `cube_memory_cutscene.gd` | Прямой `controls_locked=true/false` | Не ломать; новый ref-counted lock нужен только namespaced сценам или через bridge |
| Scene changes | несколько scripts | Синхронный `change_scene_to_file` | Legacy не переписывать сейчас; Lost Signal использовать threaded loader |
| VHS return | `InfiniteRoad.tscn`, `infinite_road_controller.gd` | Fullscreen static, distortion, return | Переиспользовать fullscreen/layout и атмосферные приёмы, не road controller |
| Infinite road | `InfiniteRoad.tscn` | Игрок идёт, UV дороги скроллится от W/S | Не подходит для vehicle loop |
| World visuals | `visual_quality_preset.gd`, `yurt_visual_director.gd` | Runtime authority для света юрты | Не подключать к Lost Signal, чтобы не перезаписывал ночной grading |
| Asset registry | `polyhaven_asset_registry.gd` | Выбор LOD/fallback Poly Haven сцен | Переиспользовать для доступной растительности/камней |
| MultiMesh utility | `polyhaven_multimesh_scatter.gd` | Chunked MultiMesh с visibility range | Переиспользовать/обобщить для forest segments |
| Visual factory | `scripts/lost_signal/visual/lost_signal_visual_factory.gd` | Текущий процедурный scaffolding | Оставить только для вспомогательной геометрии; не выдавать за финальные hero assets |
| Loading overlay | `lost_signal_scene_loader.gd` | Autoload CanvasLayer, threaded request, progress | Довести и использовать как единственный Lost Signal loader |
| Lost Signal lock | `lost_signal_input_lock.gd` | Ref-counted owners | Использовать; добавить bridge к разрешённым input domains |
| Lost Signal HUD | `lost_signal_hud.gd` | chapter/objective/subtitle/prompt/status | Использовать; добавить completion signal/очередь субтитров |
| Blink overlay | `blink_overlay.gd`, `eyelid_mask.gd` | Curved eyelids, full_dark, ref-counted lock | Использовать; гарантировать cleanup при `_exit_tree()` |

### Взаимодействие и блокировка ввода

Legacy `controls_locked` — один bool. Некоторые UI сохраняют предыдущее значение, но `cube_memory_cutscene.gd` всегда снимает блокировку в `false`. Это уже создаёт риск преждевременной разблокировки при наложении эффектов. Нельзя подключать новый `LostSignalInputLock` к legacy `Player` простым присваиванием без bridge.

Для Lost Signal нужны как минимум отдельные домены:

- блокировка ходьбы;
- блокировка mouse look;
- блокировка interaction/menu;
- полный transition lock.

Во время diner Path3D ходьба заблокирована, но local look ±18° разрешён. Во время dashcam и sink блокируются и look, и interaction, кроме управляющих клавиш текущего режима. Один глобальный `is_locked()` без доменов недостаточен, если все контроллеры слепо прекращают ввод.

Dashcam должен активироваться только после ray/Area взаимодействия с устройством. Шаблонное глобальное перехватывание E конфликтует с любым другим интерактивом.

### Диалоги и субтитры

Существующий `DialogueUI` рассчитан на yurt-style красную панель, модальные сообщения и ручное закрытие. Для точного diner flow нужны:

- speaker + line;
- auto duration;
- сигнал завершения конкретной строки;
- очередь/serial guard;
- блокировка меню до окончания реплики;
- независимая от сцены визуальная подача.

Текущий `LostSignalHUD.show_subtitle()` уже даёт auto duration и serial guard, но не выдаёт completion signal. Его нужно расширить, а не создавать ещё один SubtitleController.

### Загрузка сцен

Текущий `LostSignalSceneLoader` правильно использует threaded API и persistent CanvasLayer. Перед production acceptance ему нужны:

- `ResourceLoader.exists(path, "PackedScene")` до request;
- fade-to-black до тяжёлой смены;
- безопасный cleanup lock/overlay при `_exit_tree()` и ошибке;
- сигнал после того, как новая сцена вошла в tree хотя бы на один кадр;
- проверка, что старые SubViewport и audio nodes действительно освобождены;
- защита от повторного `transition_to()` уже есть и должна остаться.

## 6. Сцены, которые нельзя ломать

### `Main.tscn`

Текущая стартовая сцена содержит:

- `Player`;
- generated steppe и yurt;
- TV, radio и `SignalStateManager`;
- floor hatch;
- hidden temporary door в `InfiniteRoad`;
- cube memory UI;
- DialogueUI, SignalDialogueWindow, center dot;
- fullscreen/VFX layers;
- runtime interior/visual builders.

Lost Signal не должен переписывать эту композицию. Во время разработки main scene следует оставить `Main.tscn`. После полной приёмки можно либо:

- сделать `res://scenes/lost_signal/road/NightDrive.tscn` финальной `run/main_scene`; либо
- добавить отдельный явный launcher/entry, не удаляя `Main.tscn`.

ТЗ требует начинать именно с NightDrive, поэтому окончательный standalone vertical slice должен иметь documented start path на NightDrive.

### `InfiniteRoad.tscn`

Сцена запускается и должна продолжать работать. Её VHS full-screen UI использует правильные full-rect anchors и `stretch_mode=6`; этот контракт нельзя ломать. Сам controller не следует наследовать для NightDrive.

### `UndergroundSteppe.tscn`

Сцена запускается и использует тот же `Player`, DialogueUI и ReturnHatch. Изменения в Player/Input Map нужно обязательно регрессировать здесь.

## 7. Аудит доступных ассетов

### Уже доступно и пригодно

- Poly Haven CC0 shrubs: `searsia_lucida`, `searsia_burchellii`, `wild_rooibos_bush`;
- деревья `island_tree_02/03` (визуально полезны, но тяжёлые: соответствующие BIN примерно 38.8 и 75.9 MiB);
- grass/flower glTF и fallback vegetation;
- Poly Haven rocks/boulders;
- generic chunked MultiMesh builder;
- бетон, штукатурка, gravel/concrete и ряд 2K PBR материалов для служебных зон;
- security camera prop как возможный reference/secondary camera housing;
- device emission shaders и VHS/postprocess решения;
- радио white noise/electrical hum как технический reference, но происхождение каждого звука нужно подтвердить до нового использования.

### Отсутствует или не соответствует требованиям

- Generic Sedan Car с полноценным интерьером;
- Dashcam case from manifest;
- Sushi Restaurant Kit;
- Improved Feline Anthro Character;
- Ultimate House Interior Pack;
- Kenney Nature Kit;
- CDmir/TinyWorlds animated Rabbit;
- Qwantani Night runtime sky;
- Road012C 2K;
- Tiles032 2K;
- полный набор обязательных vehicle/diner/restroom/forest audio loops.

### Приоритет загрузки

1. Quaternius Sushi Restaurant Kit, Ultimate House Interior Pack.
2. Kenney Nature Kit.
3. OpenGameArt Rabbit.
4. Poly Haven Qwantani Night с runtime 4K/8K.
5. ambientCG Road012C и Tiles032 в 2K.
6. Sketchfab sedan, dashcam case и feline через авторизованную ручную загрузку, если прямой download закрыт.
7. Freesound-аудио через ручной список при требовании login.

Нельзя загружать все fallback-кандидаты одновременно. Исходные ZIP/7z, LICENSE/README и runtime import должны храниться раздельно.

## 8. Текущие незакоммиченные изменения

На момент аудита рабочее дерево уже dirty. Эти изменения нельзя сбрасывать, перетирать или автоматически форматировать целиком.

Отслеживаемые modified-файлы:

- `materials/yurt_floor/mat_yurt_main_worn_kazakh_rug.tres`;
- `project.godot`;
- `scenes/Main.tscn`;
- `scenes/player/Player.tscn`;
- `scripts/interior/yurt_interior_dressing_builder.gd`;
- `scripts/player_controller.gd`;
- `scripts/steppe_environment_builder.gd`;
- `scripts/visual_quality_preset.gd`;
- `scripts/visuals/yurt_visual_director.gd`;
- `scripts/yurt_window_vision.gd`.

Главное содержание этих изменений: rebuild визуала юрты, новые ковры, перенастройка света, Player shadow proxy, более плотный MultiMesh landscape и новые Lost Signal autoload/input entries в `project.godot`.

Untracked legacy/visual files также уже присутствуют:

- `docs/YURT_VISUAL_REBUILD_REPORT.md`;
- `materials/interior/`;
- `scenes/props/YurtEntranceRug.tscn`;
- `scenes/props/YurtTVWallRug.tscn`;
- `scripts/props/yurt_tv_wall_rug.gd` и UID;
- UID `yurt_visual_director.gd`.

Untracked Lost Signal integration на момент аудита:

- `.codex_scene_pack/`;
- `scripts/lost_signal/core/`;
- `scripts/lost_signal/road/`;
- `scripts/lost_signal/ui/`;
- `scripts/lost_signal/visual/`;
- `scenes/lost_signal/road/`;
- `scenes/lost_signal/ui/`;
- `shaders/lost_signal/`.

Так как работа идёт параллельно, точный список может расти. Перед каждым patch нужно повторять `git status --short` и читать текущую версию файла, а не полагаться на исходный HEAD.

## 9. Проверка запуска до полной интеграции

Выполнены реальные headless-прогоны текущего дерева:

| Проверка | Результат |
|---|---|
| Godot `--version` | `4.7.stable.official.5b4e0cb0f` |
| Project / текущий Main | Запускается, exit code 0 |
| `InfiniteRoad.tscn` | Запускается, exit code 0 |
| `UndergroundSteppe.tscn` | Запускается, exit code 0 |

В `Main` нет parser/runtime errors, но есть существующее предупреждение:

`Poly Haven asset missing or not imported: pine_sapling_medium`

Окружение на headless startup построило 51,200 terrain triangles, 10,800 grass instances и 1,100 flower instances. Это подтверждает, что текущая Main уже тяжёлая и её нельзя держать загруженной одновременно с Lost Signal сценами.

## 10. Целевая архитектура интеграции

```text
LostSignalFlow (единственный progression owner)
  -> LostSignalSceneLoader (threaded load + persistent fullscreen overlay)
     -> NightDrive
        -> DinerSequence
           -> Restroom -> DinerAfterMeal/ForestRoad
           -> ForestRoad
              -> RabbitEvent -> DemoComplete

LostSignalInputLock
  -> movement/look/interaction owners

Reusable scenes
  VehicleInterior
  LoopingRoad
  DashcamDevice
  LostSignalHUD
  BlinkOverlay
```

Сцены не должны знать пути друг к другу, кроме централизованных constants в `LostSignalFlow`. Они посылают semantic signals: arrival complete, order selected, meal finished, restroom exit, rabbit finished.

### Состояние

Единственный набор runtime-полей:

- `state`;
- `selected_order`;
- `meal_finished`;
- `restroom_visited`;
- `washed_face`;
- `dashcam_viewed`;
- `rabbit_event_seen`;
- `transition_in_progress`.

Сброс нового run должен быть явным. Возврат из Restroom не сбрасывает order/meal. Rabbit flag ставится до возможности recycle/повторного trigger.

### Автомобиль и дорога

- `VehicleInterior.tscn` — единственный reusable instance для NightDrive/ForestRoad;
- 6 сегментов по 60 m — хороший старт, но финальные mesh/material/props должны прийти из assets;
- автомобиль остаётся у origin;
- segment recycle без создания nodes/resources в runtime loop;
- far parallax и arrival proxy отдельны от ближних сегментов;
- Forest использует MultiMesh по каждому сегменту, а не один мировой AABB;
- near trees отдельными MeshInstance3D только в зоне фар;
- dashboard camera bob — детерминированные низкоамплитудные синусоиды.

### Dashcam

- два SubViewport не выше 640×360;
- FRONT/REAR/SPLIT меняют только update mode и UI layout;
- вне focus оба `UPDATE_DISABLED`;
- cull layers исключают салон/экран, чтобы не возник feedback;
- camera focus запускается интерактивом устройства, не глобальным E;
- Esc и повторный E возвращают исходный global transform;
- timestamp/REC/UI не требуют frame buffer delay; дешёвого rate/noise достаточно.

### Diner

- движение только Path3D/PathFollow3D;
- один cinematic rig, два основных пути и отдельный server path;
- local look ±18° отключается на двери/репликах;
- NPC используют animation offsets и простые scripted secondary motions;
- меню содержит ровно три обязательных варианта и блокирует повторный выбор;
- exact lines хранятся как data/constants и не переводятся случайно;
- Full/Partial/Empty переключаются только по `full_dark`;
- F и E одновременно активны после еды, первый transition немедленно ставит guard.

### Restroom

- отдельная сцена, не child Diner;
- ограниченный Player mode без legacy shovel/signal behavior;
- sink interaction через Area/ray и общий prompt;
- вода всегда выключается в normal completion и `_exit_tree()`;
- зеркало обновляется только в полезном угле; без тела cull mask исключает player proxy;
- return сохраняет состояние и не создаёт вторую Diner scene с потерянным meal stage.

### Forest/rabbit

- reuse VehicleInterior, LoopingRoad и Dashcam;
- trigger только по accumulated road distance;
- 0.3–0.7 s rustle lead;
- path speed синхронизируется с фактическим animation clip;
- rabbit доступен main camera и FRONT layer;
- hide только после конца path + минимум 1 s;
- событие не привязано к recycle одного segment node.

## 11. Предполагаемые создаваемые файлы

Ниже production-структура, адаптированная к уже выбранному namespace. Часть core/road/UI файлов уже существует как незавершённая заготовка и должна быть доведена, а не создана второй раз.

### Scenes

- `scenes/lost_signal/road/NightDrive.tscn`;
- `scenes/lost_signal/road/VehicleInterior.tscn`;
- `scenes/lost_signal/road/LoopingRoad.tscn`;
- `scenes/lost_signal/road/DashcamDevice.tscn`;
- `scenes/lost_signal/diner/DinerExterior.tscn`;
- `scenes/lost_signal/diner/DinerInterior.tscn`;
- `scenes/lost_signal/diner/DinerSequence.tscn`;
- `scenes/lost_signal/diner/DinerNPC.tscn`;
- `scenes/lost_signal/restroom/Restroom.tscn`;
- `scenes/lost_signal/restroom/SinkInteraction.tscn`;
- `scenes/lost_signal/forest/ForestRoad.tscn`;
- `scenes/lost_signal/forest/RabbitCrossing.tscn`;
- `scenes/lost_signal/ui/LostSignalHUD.tscn`;
- `scenes/lost_signal/ui/BlinkOverlay.tscn`;
- `scenes/lost_signal/ui/DinerMenuUI.tscn`.

### Scripts

- `scripts/lost_signal/core/lost_signal_flow.gd`;
- `scripts/lost_signal/core/lost_signal_scene_loader.gd`;
- `scripts/lost_signal/core/lost_signal_input_lock.gd`;
- `scripts/lost_signal/road/night_drive.gd`;
- `scripts/lost_signal/road/looping_road.gd`;
- `scripts/lost_signal/road/vehicle_interior.gd`;
- `scripts/lost_signal/road/limited_look.gd`;
- `scripts/lost_signal/road/dashcam_controller.gd`;
- `scripts/lost_signal/diner/cinematic_path_controller.gd`;
- `scripts/lost_signal/diner/diner_sequence.gd`;
- `scripts/lost_signal/diner/diner_menu.gd`;
- `scripts/lost_signal/diner/diner_npc.gd`;
- `scripts/lost_signal/diner/meal_presenter.gd`;
- `scripts/lost_signal/restroom/restroom_controller.gd`;
- `scripts/lost_signal/restroom/sink_controller.gd`;
- `scripts/lost_signal/forest/forest_sequence.gd`;
- `scripts/lost_signal/forest/rabbit_crossing.gd`;
- `scripts/lost_signal/ui/lost_signal_hud.gd`;
- `scripts/lost_signal/ui/blink_overlay.gd`;
- `scripts/lost_signal/ui/eyelid_mask.gd`;
- `scripts/lost_signal/visual/lost_signal_visual_factory.gd` — только helper/fallback геометрия.

### Shaders/materials/audio

- `shaders/lost_signal/dashcam_screen.gdshader`;
- `shaders/lost_signal/water_stream.gdshader`;
- night road, vehicle glass/interior, neon, tile, wet floor, mirror и food materials в `materials/lost_signal/`;
- `default_bus_layout.tres` с `Ambience`, `Vehicle`, `InteriorRoom`, `SFX`, `UI`, `Dialogue`;
- runtime audio в `assets/audio/lost_signal/` с отдельными source/license records.

### Assets/docs

- runtime assets в namespaced подпапках `assets/lost_signal/vehicle`, `diner`, `characters`, `restroom`, `forest`, `rabbit`, `environment`, `materials`;
- `_incoming_assets/` только как staging, не runtime dependency;
- `ASSET_CREDITS.md`;
- `docs/ASSET_RESEARCH.md`;
- `docs/VISUAL_REFERENCES.md`;
- `docs/MANUAL_DOWNLOADS.md`, если login блокирует файлы;
- `docs/IMPLEMENTATION_REPORT.md`.

## 12. Предполагаемые изменяемые существующие файлы

Минимальный production diff должен ограничиться:

- `project.godot` — Autoload, Input Map и только в финале main scene;
- `scripts/player_controller.gd` — только если Restroom reuse требует mode/lock bridge и безопасного InputMap merge;
- `scenes/player/Player.tscn` — только exported Restroom mode defaults, без изменения legacy defaults;
- `.gitignore` — только после решения, как воспроизводимо поставлять runtime assets;
- при необходимости `scripts/game_state.gd` — только если Lost Signal state должен переживать выход из namespaced flow/save-load.

Не требуется менять `Main.tscn`, `InfiniteRoad.tscn`, `UndergroundSteppe.tscn`, TV/radio/cube scenes и существующие shaders для реализации Lost Signal. Любая такая правка должна иметь отдельное обоснование и регрессионный тест.

## 13. Риски и меры

| Приоритет | Риск | Последствие | Мера |
|---|---|---|---|
| P0 | Procedural primitives останутся вместо выбранных hero assets | Прямой провал критерия качества | Использовать scaffolding только для flow; заменить до acceptance |
| P0 | Sketchfab/Freesound требуют login | Нет sedan/cat/dashcam/audio | `MANUAL_DOWNLOADS.md`, точные URLs/targets, не брать reuploads |
| P0 | `interact` заранее убирает legacy ЛКМ event | Незаметная регрессия текущего Player | Safe merge InputMap либо явно принять E-only |
| P0 | Новый loader/flow дублируется ещё одной реализацией | Race transitions/state loss | Сохранить единственные namespaced Autoloads |
| P0 | Dashcam глобально ловит E | Нельзя взаимодействовать с другими объектами | Activation Area/ray + explicit availability |
| P0 | Параллельные правки dirty worktree | Потеря пользовательского visual rebuild | Patch только актуальных строк; никогда reset/checkout |
| P1 | Compatibility renderer не даёт ожидаемые эффекты | Плоский/неработающий ночной visual | World fog/mesh haze/baked light; не обещать Forward+ эффекты |
| P1 | 984 MiB 16K EXR попадёт в runtime | Огромная RAM/VRAM и load hitch | Qwantani 4K/8K с import size limit/mipmaps |
| P1 | Existing assets уже ~2.2 GiB | Рост проекта и import times | Загружать только выбранные assets, runtime 1K–2K |
| P1 | InputLock только global bool semantics | Diner look блокируется вместе с movement | Домены/режимы lock или controller-specific owner checks |
| P1 | SceneLoader меняет scene до полного fade/ready | Pop/hitch и ранний unlock | Fade, 1–2 process frames, ready handshake |
| P1 | Нет subtitle completion signal | Flow зависит от случайных timers | HUD signal/awaitable line completion |
| P1 | Restroom reuse запускает shovel/signal/crouch code | Неверное управление и F/2 conflict | Explicit Lost Signal player mode |
| P1 | Mirror/dashcam SubViewport остаются active | GPU cost и feedback loops | UPDATE_DISABLED вне видимости; cull masks; automated assertions |
| P1 | Forest uses heavy existing island trees | VRAM/draw-call spikes | Kenney/LOD/MultiMesh; существующие деревья только редкими hero props |
| P1 | `.gitignore` скрывает runtime assets | Сцена работает только на одной машине | Git LFS или воспроизводимый external asset pipeline |
| P2 | Legacy `controls_locked` не ref-counted | Старый overlay может снять чужой lock | Не смешивать locks без bridge; регрессировать cube/dialogue |
| P2 | Нет audio buses/reverb isolation | Master clipping или reverb на всю игру | Создать bus layout, лимитировать loops/peaks |
| P2 | Нет save system | Состояние теряется при полном restart | Для vertical slice достаточно runtime; документировать |
| P2 | Existing missing pine sapling warning | Нечистый Output | Добавить asset либо исключить registry entry отдельно от Lost Signal |

## 14. Порядок интеграции

1. Зафиксировать единственные core Autoloads и Input Map без регрессии legacy interaction.
2. Довести loader, lock domains, HUD subtitle completion и Blink cleanup.
3. Проверить NightDrive на инженерной геометрии: 6 сегментов, camera limits, arrival transition.
4. Подключить реальный sedan/interior и DashcamDevice; проверить FRONT/REAR/SPLIT/OFF.
5. Импортировать diner/NPC/food assets и собрать внешний/внутренний layout.
6. Реализовать exact diner flow и три meal states.
7. Собрать отдельный Restroom, sink, water shader, mirror update gating.
8. Собрать ForestRoad на том же VehicleInterior/RoadLoop/Dashcam.
9. Подключить rigged rabbit, animation/path sync и one-shot distance trigger.
10. Сделать единый lighting/material/audio pass под Compatibility renderer.
11. Выполнить headless tests всех сцен, затем три ручных clean playthrough из checklist.
12. Только после полной приёмки переключить/document standalone start scene и заполнить implementation/performance report.

## 15. Обязательная регрессия

После изменений `project.godot`, Player или общей UI/input инфраструктуры обязательно проверить:

- `Main.tscn` загружается без ошибок;
- WASD, mouse look, E и center dot;
- cube запускает 13-секундный cutscene и возвращает управление;
- TV/radio combinations и F trigger;
- floor hatch и ReturnHatch;
- temporary door ведёт в `InfiniteRoad`;
- `InfiniteRoad` сохраняет fullscreen VHS return;
- `UndergroundSteppe` запускается и возвращается;
- новые полноэкранные layers действительно покрывают весь viewport.

Для Lost Signal выполнить checklist без сокращений:

- три заказа;
- туалет с умыванием и пропуск туалета;
- FRONT/REAR/SPLIT и повторный E/Esc;
- быстрые повторные order/F/E;
- inactive SubViewport;
- точные реплики;
- Full/Partial/Empty только в полной темноте;
- rabbit ровно один раз;
- отсутствие active audio/cameras старой сцены;
- Output без parser errors, missing resources и invalid calls;
- измеренные FPS, draw calls, shadow lights и приблизительный VRAM budget на RTX 3050/1080p.

## 16. Критерий продолжения после аудита

Аудит подтверждает, что интеграция технически возможна без перестройки существующего проекта. Безопасная стратегия — namespaced Lost Signal scenes плюс три единственных Autoload-сервиса, reuse существующих interaction/UI/MultiMesh-паттернов и полная изоляция legacy Main.

Следующий допустимый шаг — импорт только выбранных assets и доведение уже созданного Lost Signal scaffolding. Нельзя объявлять vertical slice production-ready, пока процедурные автомобиль/NPC/лес остаются финальной видимой геометрией, нет лицензированных source records, нет всех четырёх сцен и не выполнены три полных прохождения.
