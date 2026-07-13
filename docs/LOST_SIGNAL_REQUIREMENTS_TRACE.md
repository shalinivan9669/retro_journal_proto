# Lost Signal — трассировка требований, интеграции и приёмки

Дата инженерной сверки: 2026-07-13  
Целевая версия: Godot `4.7.stable.official.5b4e0cb0f`  
Назначение документа: единый production-контракт между постановкой, реализацией и QA. Это не отчёт о завершении и не разрешение считать процедурный blockout финальным визуалом.

## 1. Покрытие исходных материалов

Архив `C:\Users\Linux\Downloads\Lost_Signal_Codex_Scene_Pack.zip` проверен с SHA-256 `1EDED0378125BDC70021470B89BE9E4E73CFD94A8DC0EFC381EA2350EF83D83E`. Распакованная копия содержит 22 файла, 156131 байт и 3429 строк. Все перечисленные ниже файлы прочитаны полностью, включая пустые строки, typed GDScript, JSON и shader-код.

### Внешние инструкции

| Источник | Строк | SHA-256 | Нюанс |
|---|---:|---|---|
| `attachments/10d1371c-.../pasted-text.txt` | 1007 | `C8658710C952D7368FFA93EDA88180FEDCA8AFA2E466C15F17B9B6E83367B8E9` | Наиболее полный внешний production-бриф |
| `attachments/671f8385-.../pasted-text.txt` | 853 | `7B5148EB1560D495468C6E248C8138046AA9C3B112BD25AB606B2A43FE0F9E25` | Файл физически обрывается на фразе `2. В траве появляется корот`; недостающий хвост восстановлен только из полных источников архива, не придуман |
| `.codex_scene_pack/Pasted text(1).txt` | 1476 | `9A594F488B04365357D2799EAC5AAB14DFA404B73E8F0234B6062B9084D85BA8` | Исходное полное ТЗ |

### Документация и данные scene pack

| Файл | Строк | Роль |
|---|---:|---|
| `README_RU.md` | 40 | Правила применения пакета и юридическая модель загрузок |
| `CODEX_MASTER_PROMPT.md` | 171 | Сводный обязательный production-бриф |
| `docs/ASSET_MANIFEST.md` | 131 | Выбранные ассеты, fallback, лицензии и ссылки |
| `docs/SCENE_BLUEPRINT.md` | 343 | Обязательная постановка, размеры, тайминги и деревья сцен |
| `docs/IMPLEMENTATION_CHECKLIST.md` | 114 | Фазовая и техническая приёмка |
| `docs/ASSET_CREDITS_TEMPLATE.md` | 34 | Минимальный формат атрибуции |
| `tools/asset_manifest.json` | 89 | 10 обязательных загрузок и целевые каталоги |

### Архитектурные примеры и shaders

| Файл | Строк | Статус использования |
|---|---:|---|
| `scripts/core/GameFlow.gd` | 77 | Только архитектурный пример; не копировать без исправлений ниже |
| `scripts/core/InputLock.gd` | 45 | База owner/ref-count lock |
| `scripts/core/SceneLoader.gd` | 80 | База threaded loader |
| `scripts/diner/CinematicPathController.gd` | 71 | База движения по PathFollow3D |
| `scripts/diner/DinerMenuController.gd` | 71 | База меню и защиты от повторного заказа |
| `scripts/diner/DinerSequenceController.gd` | 173 | База локальной state machine; монтаж еды требует исправления |
| `scripts/forest/RabbitCrossingController.gd` | 75 | База одноразового события |
| `scripts/restroom/SinkController.gd` | 83 | База интеракции с раковиной |
| `scripts/road/DashcamController.gd` | 116 | База focus/feed logic; ввод должен идти через существующее взаимодействие |
| `scripts/road/LimitedLookController.gd` | 61 | База ограниченного обзора |
| `scripts/road/RoadLoopController.gd` | 68 | База переиспользования сегментов |
| `scripts/ui/BlinkController.gd` | 59 | База eyelid transition; нужен teardown-safe lock |
| `shaders/dashcam_screen.gdshader` | 30 | База только для экрана регистратора |
| `shaders/water_stream.gdshader` | 22 | База воды; содержит несовместимый render mode Godot 3 |

## 2. Приоритет требований и разрешённые неоднозначности

При конфликте формулировок применяется следующий порядок:

1. Текущий пользовательский запрос и полный внешний production-бриф.
2. Исходный `Pasted text(1).txt` и `SCENE_BLUEPRINT.md`; оба названы обязательными.
3. `CODEX_MASTER_PROMPT.md` и `README_RU.md`.
4. `IMPLEMENTATION_CHECKLIST.md`.
5. GDScript/shader-файлы — только примеры архитектуры, не нормативное поведение.

Принятые строгие трактовки:

- Дорога имеет ровно 6 переиспользуемых сегментов. Ранний диапазон «4–8» уступает более позднему точному требованию.
- Rabbit event запускается по накопленной дистанции. Таймер допускается только как диагностический эквивалент дистанции и не является источником истины.
- FRONT/REAR SubViewport вне focus не «реже обновляются», а имеют `UPDATE_DISABLED`.
- `Full -> Partial -> Empty` меняется только внутри окна `full_dark`, не после полного открытия глаз.
- После еды выбор не автоматический: обе подсказки F/E видны одновременно.
- Выход `F` из туалета трактуется как возврат к автомобилю и переход в ForestRoad через blink: это соответствует внешнему разделу «если вышел из туалета» и тесту «туалет -> возврат к машине». Заказ и состояние еды всё равно сохраняются. Если режиссёрски выбран возврат к столику, он допустим только как явно задокументированное отклонение и требует затем отдельного E-перехода.
- Процедурные BoxMesh/CylinderMesh допустимы для blockout и для небольших оригинальных props с фасками/материалами. Они не закрывают финальные требования к автомобилю, NPC, зайцу, закусочной и лесному набору.

## 3. Снимок существующего проекта и контракт интеграции

### Найдено

- `project.godot`: Godot 4.7, `run/main_scene="res://scenes/Main.tscn"`, renderer `gl_compatibility`, fullscreen 1920×1080, 3D scale 0.9.
- Исходный Autoload до текущей работы: только `GameState`, занятый состоянием ритуала Albasty.
- В рабочем дереве уже создаётся один scoped-набор `LostSignalInputLock`, `LostSignalSceneLoader`, `LostSignalFlow`. Не создавать параллельно ещё один `GameFlow`/loader/lock для этого vertical slice.
- `Player.tscn` и `player_controller.gd`: `CharacterBody3D`, центрированный `RayCast3D` на 4.5 m, проход через до 10 неинтерактивных коллайдеров, вызовы `interact(dialogue_ui)` и `get_interaction_prompt()`.
- Существующая блокировка игрока — простой `controls_locked: bool`; она пока не связана с owner-based Lost Signal lock.
- Существующий `DialogueUI`: группа `dialogue_ui`, сообщение, speaker label, prompt и mouse-choice buttons. Нет сигнала окончания реплики, timed subtitle API, 1/2/3 shortcuts и полноценной keyboard focus navigation.
- Legacy-переходы вызывают `change_scene_to_file()` напрямую; для новых Lost Signal сцен должен применяться один threaded loader, не затрагивая работающие legacy-переходы до отдельной регрессии.
- `default_bus_layout.tres` отсутствует; фактически нет требуемого набора аудиошин.
- В `_incoming_assets/` на момент аудита файлов нет. Выбранные sedan/diner/cat/rabbit/nature/road/tile ассеты в runtime-дереве не найдены.
- `Main.tscn` запускается без parser/runtime errors; есть существующее предупреждение об отсутствующем `pine_sapling_medium`. `InfiniteRoad.tscn` запускается чисто.
- Рабочее дерево было грязным до/во время интеграции. Нельзя откатывать или перезаписывать изменения yurt/player/visual systems, не относящиеся к Lost Signal.

### Решение по ответственности

| Область | Переиспользовать/расширить | Не делать |
|---|---|---|
| Legacy global state | Оставить `GameState` владельцем старых механик | Не копировать Albasty-state в LostSignalFlow |
| Lost Signal state | Один `LostSignalFlow` владеет только состоянием vertical slice | Не хранить те же flags ещё в сценах или `GameState` |
| Взаимодействие | Центрированный ray, методы `interact`/`get_interaction_prompt`, центр-точка | Не перехватывать любой E глобальным dashcam `_unhandled_input` |
| UI | Общий визуальный язык; расширить timed subtitle/finished event либо дать LostSignalHUD чётко ограниченную роль | Не оставлять два конкурирующих prompt/subtitle слоя одновременно |
| Input lock | Owner/ref-count; контроллеры читают один сервис | Не смешивать owner lock и прямое `controls_locked=false`, которое может снять чужую блокировку |
| Loading | Один Lost Signal threaded loader и persistent overlay | Не вызывать direct `change_scene_to_file()` внутри Lost Signal цепочки |
| Vehicle | Один instance `VehicleInterior` для NightDrive и ForestRoad | Не форкать два автомобиля с независимыми исправлениями |
| Main/legacy | `Main.tscn`, cube, door->InfiniteRoad и VHS остаются рабочими | Не заменять/ломать существующие маршруты ради demo entry |

### Renderer decision gate

Текущий renderer — Compatibility. По официальной документации Godot 4.x он поддерживает depth/height fog и baked lightmap rendering, но не поддерживает volumetric fog, Decal nodes, SSR, SDFGI/SSIL и HDR rendering; ReflectionProbe ограничены двумя на mesh. Источники: [renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [Godot 4.7 rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html).

До visual lock необходимо зафиксировать одно из двух решений:

- Сохранить Compatibility: headlight scattering имитировать дешёвыми beam meshes/particles; грязь и дорожные повреждения делать mesh overlays/secondary materials вместо Decal; мокрые отражения — roughness/material + ограниченные ReflectionProbe; лес — depth/height fog, без FogVolume.
- Перейти desktop renderer на Forward+: это лучше соответствует RTX 3050 и исходной постановке, но считается проектным изменением. После переключения обязательна полная регрессия `Main.tscn`, `InfiniteRoad.tscn`, `UndergroundSteppe.tscn`, fullscreen overlays и всех существующих shaders. Mobile/web fallback можно оставить Compatibility.

Нельзя строить сцену на FogVolume/Decal при Compatibility и считать отсутствие эффекта «настройкой качества».

## 4. Каноническая state machine

Обязательные persistent fields:

| Поле | Тип/начало | Когда меняется | Инвариант |
|---|---|---|---|
| `state` | enum / `NIGHT_DRIVE` | Только валидным переходом | Сцена не назначает произвольный будущий state |
| `selected_order` | `StringName(&"")` | Ровно один раз в menu | Только `lagman`, `cutlet`, `eggs` |
| `meal_finished` | `false` | На `full_dark` третьего blink | Не становится true до Empty |
| `restroom_visited` | `false` | При принятом F-переходе | Не сбрасывается при загрузке Restroom/Forest |
| `washed_face` | `false` | На `full_dark` wash sequence | Повторное E не повторяет state event |
| `dashcam_viewed` | `false` | После успешного входа в focus | Не ставить при отклонённом/прерванном Tween |
| `rabbit_event_seen` | `false` | При принятом старте event | Блокирует повтор даже при recycle/выходе во время event |
| `transition_in_progress` | `false` | До первого await/request | Снимается на ready success или controlled failure |

Обязательная цепочка:

| From | Trigger/guard | To | Побочный эффект | QA |
|---|---|---|---|---|
| `NIGHT_DRIVE` | накоплена arrival distance | `DINER_ARRIVAL` | плавное снижение скорости, proxy diner | Нет pop-in |
| `DINER_ARRIVAL` | загрузка Diner принята | `DINER_ENTERING` | input lock, persistent loading/blink | Двойной request отклонён |
| `DINER_ENTERING` | EntryPath завершён | `DINER_AT_COUNTER` | cashier look, greeting | Camera не пересекла дверь/NPC |
| `DINER_AT_COUNTER` | greeting завершён | `DINER_MENU` | physical menu + Control overlay | Ввод 1/2/3, mouse, focus |
| `DINER_MENU` | валидный single order | `DINER_GOING_TO_TABLE` после реакции | register animation/sound, exact confirmation | Повторный выбор невозможен |
| `DINER_GOING_TO_TABLE` | TablePath завершён | `DINER_WAITING_FOR_FOOD` | seated camera | Без teleport |
| `DINER_WAITING_FOR_FOOD` | Blink 1 / server path | `DINER_FOOD_DELIVERED` | Full и реплика сотрудника | Блюдо соответствует ID |
| `DINER_FOOD_DELIVERED` | Blink 2 `full_dark` | `DINER_EATING` | Full off, Partial on | Нет видимого pop |
| `DINER_EATING` | Blink 3 `full_dark` | `DINER_AFTER_MEAL` | Partial off, Empty on, `meal_finished=true` | Все 3 заказа |
| `DINER_AFTER_MEAL` | UI готов | `RESTROOM_AVAILABLE` | F и E одновременно | Ничего не выбирается само |
| `RESTROOM_AVAILABLE` | F и guard | `RESTROOM_INSIDE` | `restroom_visited=true`, blink/load | E в тот же кадр проигнорирован |
| `RESTROOM_AVAILABLE` | E и guard | `DINER_LEAVING` | blink/load Forest | Diner audio/camera выгружены |
| `RESTROOM_INSIDE` | wash E | тот же state | `washed_face=true` | Teardown всегда выключает воду |
| `RESTROOM_INSIDE` | exit F и guard | `BACK_IN_CAR` | blink/load Forest | Сохранены order/meal/wash |
| `DINER_LEAVING` | Forest ready | `BACK_IN_CAR` | глаза открываются в салоне | Старых Camera/Audio/SubViewport нет |
| `BACK_IN_CAR` | intro finished | `FOREST_DRIVE` | road distance reset для forest trigger | Тот же VehicleInterior |
| `FOREST_DRIVE` | distance threshold и unseen | `RABBIT_EVENT` | rustle, speed -10..20% | Ровно один старт |
| `RABBIT_EVENT` | rabbit offscreen + >=1 s | `DEMO_COMPLETE` | restore speed, disable controller | Нет второго события |

Если реализация объединяет мгновенные `RESTROOM_AVAILABLE`, `DINER_LEAVING` или `BACK_IN_CAR`, enum всё равно должен сохранять наблюдаемую последовательность либо отчёт обязан объяснить эквивалент и покрыть те же guards. Предпочтение — сохранить полный enum из брифа.

## 5. Точные строки и input contract

### Реплики — изменять нельзя

| Speaker | Text | Полностью отображаемая строка |
|---|---|---|
| `Кассир` | `Доброй ночи. Что будете заказывать?` | `Кассир: Доброй ночи. Что будете заказывать?` |
| `Кассир` | `Спасибо за выбор. Ас болсын.` | `Кассир: Спасибо за выбор. Ас болсын.` |
| `Сотрудник` | `Ваш заказ.` | `Сотрудник: Ваш заказ.` |

Если UI хранит speaker и text отдельно, визуальный результат и punctuation должны совпадать с таблицей.

### Меню — ровно три блюда

| Key | Stable ID | Display text |
|---:|---|---|
| 1 | `&"lagman"` | `1 — Лагман` |
| 2 | `&"cutlet"` | `2 — Котлета с картофелем` |
| 3 | `&"eggs"` | `3 — Яичница с колбасой` |

### Подсказки

- `E — посмотреть видеорегистратор`
- `F — зайти в туалет`
- `E — вернуться в машину`
- `E — умыться`
- `F — вернуться`

### Input Map

| Action | Binding | Scope |
|---|---|---|
| `interact` | E | world interaction, dashcam enter/exit, sink, return-to-car choice |
| `restroom` | F | after-meal restroom choice и restroom exit |
| `menu_option_1/2/3` | 1/2/3 | menu и dashcam modes по текущему state |
| `cancel` | Esc | dashcam exit; не должен закрыть/сломать обязательную cashier reaction |
| mouse | relative motion | limited look; visible cursor только для меню |
| movement | W/A/S/D | только Restroom limited player; не NightDrive/Diner cinematic |

Одинаковые клавиши допустимы только при state/context routing. Один глобальный `_unhandled_input` dashcam не должен забирать E, когда центр-точка не смотрит на устройство.

## 6. Трассировка требований к реализации и тестам

### CORE

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-CORE-001 | Один state owner | Все seven flags и current state только в `LostSignalFlow`; сцены посылают события | Поиск не находит дублирующих writable flags |
| LS-CORE-002 | Защита transitions | Guard ставится синхронно до request/await; F+E в одном кадре дают один path | Stress test 30 быстрых F/E |
| LS-CORE-003 | Owner lock | acquire/release симметричны; teardown-safe; несколько владельцев | blink+loader overlap не разблокирует раньше времени |
| LS-CORE-004 | Partial input lock | Отдельно разрешать local look и запрещать movement/interact | Diner path: walk input не влияет, ±18° look работает |
| LS-CORE-005 | Threaded loading | `load_threaded_request/get_status/get`, progress по кадрам | Нет blocking loop; progress изменяется |
| LS-CORE-006 | Ready-safe transition | Loader не снимает lock/overlay до готовности новой сцены | New scene `_ready()` видит целевой state |
| LS-CORE-007 | Failure recovery | При missing/invalid PackedScene state и lock откатываются, UI сообщает ошибку | Инъекция неверного path не soft-lock'ит игру |
| LS-CORE-008 | Scene cleanup | Old Camera3D, audio, SubViewport и references освобождены | Remote tree/profiler после каждого перехода |
| LS-CORE-009 | Persistent transition visual | Blink/loading layer не уничтожается вместе со старой сценой либо имеет `_exit_tree` cleanup | Scene switch на `full_dark` не оставляет lock |
| LS-CORE-010 | Legacy safety | Main, cube, door->InfiniteRoad, InfiniteRoad/VHS остаются рабочими | Отдельные headless и ручные regressions |

### NIGHT DRIVE / VEHICLE / ROAD

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-ROAD-001 | Машина у world origin | Двигаются road/near props, не car world transform | 3 минуты без precision drift |
| LS-ROAD-002 | Ровно 6 сегментов | Одинаковый forward axis/pivot; длина выбранная в 48–72 m, рекомендуемо 60 m | Node count стабилен, 3 минуты без шва |
| LS-ROAD-003 | Без churn | Recycle переносит существующий segment; deterministic variants | Нет роста Object/Node count |
| LS-ROAD-004 | Параллакс | Near 100% speed, far 10–25%, sky/horizon 0% | Видео/визуальная проверка |
| LS-ROAD-005 | Скорость | Старт 18–23 m/s; плавные изменения | Нет скачка transform/аудио pitch |
| LS-ROAD-006 | Полный автомобиль | Кузов, капот, интерьер, wheel, dashboard, selector, seats, pillars, doors, mirrors, windshield, headlights, dashcam | Driver camera не видит дыр с предельных углов |
| LS-ROAD-007 | Limited look | yaw ±55°, pitch -28°..+22°, без 180° и clipping | Automated angle assertions + ручной осмотр |
| LS-ROAD-008 | Subtle motion | engine 0.5–1.5 mm, roll <=0.08°, rare bump 2–5 mm; без random shake каждый кадр | Motion не вызывает дискомфорт |
| LS-ROAD-009 | Headlights | Реальные SpotLight3D, 45–70 m shadow distance, физически на car | Разметка/кусты/rabbit читаются |
| LS-ROAD-010 | Sky | Тёмно-синий, острые звёзды, Milky Way, слабый horizon; runtime source 4K–8K, не 24K | VRAM/import settings и screenshot |
| LS-ROAD-011 | Arrival | Proxy стартует 350–500 m; slowing начинается за 10–14 s, 4 m/s -> 0 | Нет pop-in, engine idle синхронен |
| LS-ROAD-012 | Asset gate | Procedural car/road — blockout до выбранных licensed assets/PBR | Credits + импортированные source/runtime files |

### DASHCAM

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-CAM-001 | Физическое устройство | Корпус, mount, screen, buttons, LED, REC, timestamp, front/rear camera; у mirror | Видно из driver view без HUD focus |
| LS-CAM-002 | Interaction | Enter только по center-ray/Area3D; E repeat/Esc exit | E вне устройства не открывает dashcam |
| LS-CAM-003 | Modes | FRONT/REAR/SPLIT/OFF; 1/2/3 | Все modes переключаются без stale frame |
| LS-CAM-004 | Feeds | Две Camera3D + два SubViewport <=640×360 | Inspector/runtime assertion |
| LS-CAM-005 | Update policy | FRONT только front; REAR только rear; SPLIT оба; OFF оба disabled | Profiler и property check |
| LS-CAM-006 | Cull masks | Экран/UI/лишний салон исключены, нет feedback | Camera feeds не видят собственный screen |
| LS-CAM-007 | Focus | Tween к anchor 28–40 cm от screen; точный возврат transform/FOV | 20 входов/выходов без drift |
| LS-CAM-008 | Effects scope | Noise/scanline/distortion/exposure только screen material | Основная Camera3D чистая |
| LS-CAM-009 | Teardown | `_exit_tree` disabled feeds + release lock | Transition во время focus без orphan viewport |
| LS-CAM-010 | Rabbit coverage | Rabbit виден MAIN и FRONT; REAR кратко при допустимом угле | Run capture каждого feed |

### DINER / MENU / MEAL

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-DIN-001 | Visual direction | Чёрная ночь, cold white neon, warm counter, readable wet surfaces, без cheap horror | Approved screenshot set |
| LS-DIN-002 | Functional set | Exterior, windows, sign, parking, counter, register, kitchen hints, tables, props | Scene inventory |
| LS-DIN-003 | 4 roles | Cashier, cat visitor, second anthro, server | Все видимы/функциональны |
| LS-DIN-004 | Living NPC | Unsynced blink/head/ears/tail/cup/look/register/tray idles | Не стартуют на одной фазе |
| LS-DIN-005 | Entry path | 0–2.5 s observe, 2.5–7 parking, 7–8.2 door, 8.2–13 interior, 13–16 counter | Timeline capture; no collision |
| LS-DIN-006 | Human bob | 1.7–2.0 Hz, vertical 1.2–2.2 cm, lateral 0.3–0.7 cm, fade 0.25–0.4 s | Camera telemetry |
| LS-DIN-007 | Local look | ±18° while moving, centered on door/lines | Movement path unaffected |
| LS-DIN-008 | Exact greeting | Первая точная реплика до menu | String assertion |
| LS-DIN-009 | Menu accessibility | 3 exact dishes; 1/2/3, mouse, keyboard focus | Keyboard-only и mouse-only runs |
| LS-DIN-010 | Single order | Stable ID stored once; buttons disabled/marked | Rapid key/mouse spam |
| LS-DIN-011 | Exact confirmation | Register action/sound, затем точная фраза; menu closes after reaction | Timeline/string assertion |
| LS-DIN-012 | Table path | Второй Path3D, camera садится; видны hall/register/server path | Нет teleport/clipping |
| LS-DIN-013 | Meal variants | Для каждого ID существуют Full/Partial/Empty | 9 scene objects/resources |
| LS-DIN-014 | Full-dark swaps | Stage changes connected to `full_dark`, не к `blink_finished` | Frame capture не видит pop |
| LS-DIN-015 | After-meal agency | F и E одновременно, только после Empty/meal_finished | До еды F/E не переходят |

### RESTROOM / SINK / MIRROR

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-RST-001 | Отдельная сцена | Не preloaded/visible внутри Diner tree | Memory/remote tree |
| LS-RST-002 | Размер/стиль | Около 6×4.5 m, cold tile/panels, dirty grout, logical wet zones, no random horror | Layout review |
| LS-RST-003 | Fixtures | 2 sinks, mirror, soap, dryer, bin, stalls/toilets/urinals/paper | Scene inventory |
| LS-RST-004 | Technical zone | Mop, bucket, cleaners, pipes, vents, drain, panel, wet sign сгруппированы | Layout review |
| LS-RST-005 | Limited movement | Несколько метров W/A/S/D + look, без скрытых corridors | Collision walkthrough |
| LS-RST-006 | Wash sequence | Lock -> focus 0.35–0.55 s -> faucet/water/particles/audio -> dip -> blink -> state -> stop -> return -> unlock | Timeline assertion |
| LS-RST-007 | Water | Transparent mesh + scrolling normal + impact particles + wet mark; no fluid sim | Shader/material review |
| LS-RST-008 | Teardown safety | Water/audio/particles off in normal finish и `_exit_tree` | Forced scene exit mid-wash |
| LS-RST-009 | Mirror | ~512×512, cull mask, disabled when not visible; no missing-body artifact | Turn-away profiler test |
| LS-RST-010 | Exit | F -> blink -> car/Forest; persistent state intact | Run 1 state dump |

### FOREST / RABBIT / END

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-FOR-001 | Vehicle reuse | Instance той же VehicleInterior/RoadLoop-compatible base | Resource path identity |
| LS-FOR-002 | Visible corridor | 6 segments; 2–4 MultiMesh groups per segment; road visible 45–60 m | AABB/visibility debug |
| LS-FOR-003 | Near lighting | 0–25 m отдельные MeshInstance3D; far MultiMesh без dynamic shadows | Shadow profiler |
| LS-FOR-004 | Determinism | Segment vegetation seeded; recycle без pop | Multi-cycle capture |
| LS-RAB-001 | Distance trigger | 25–40 s equivalent accumulated distance; one-shot flag set at accepted start | Recycle/stress test |
| LS-RAB-002 | Staging | 0.3–0.7 s grass rustle/audio, затем path 12–18 m at 7–11 m/s | Timeline capture |
| LS-RAB-003 | Natural motion | Run/jump synced to path, no root-motion double transform/sliding | Slow-motion review |
| LS-RAB-004 | Non-horror | No stinger, collision, blood, camera jump, supernatural behavior | Audio/event review |
| LS-RAB-005 | Car response | Speed -10..20%, не полный stop, затем restore | Speed telemetry |
| LS-RAB-006 | Safe hide | Endpoint скрыт травой; минимум 1 s и rabbit вне frame до hide | MAIN/FRONT/REAR capture |
| LS-RAB-007 | Completion | `rabbit_event_seen=true`, process disabled, `DEMO_COMPLETE` | Второй вызов no-op |

### ART / AUDIO / PERFORMANCE

| ID | Requirement | Implementation contract | Acceptance evidence |
|---|---|---|---|
| LS-ART-001 | Unified style | Quaternius/Kenney desaturated, coherent PBR/roughness/texel density | Material audit |
| LS-ART-002 | Texture budgets | Mostly 1K–2K, 4K only hero large surfaces, sky 4K–8K runtime | Import report |
| LS-AUD-001 | Buses | Master, Ambience, Vehicle, InteriorRoom, SFX, UI, Dialogue | `default_bus_layout.tres` + runtime check |
| LS-AUD-002 | Local reverb | Short room reverb only InteriorRoom in diner/restroom | Master не проходит reverb |
| LS-AUD-003 | Beds/oneshots | Engine/tire/cabin/wind; diner appliances/neon/dishes/crowd; water; forest/insects/rustle | No clipping, seamless loops |
| LS-PERF-001 | Target | 60 FPS, RTX 3050, 1080p, declared renderer/settings | Captured profiler values per scene |
| LS-PERF-002 | Vegetation | Segmented MultiMesh, visibility ranges/LOD | Draw/instance counts |
| LS-PERF-003 | Interiors | Occluders; baked/mixed light where renderer allows; few shadow lights | Profiler + bake assets |
| LS-PERF-004 | Collision | Primitive/convex; no small-prop trimesh | Scene scan |
| LS-PERF-005 | Runtime lifecycle | No per-frame create/free, unnecessary process, hidden SubViewport, retained heavy scene | Stable monitor counters |

## 7. Asset and licensing gates

### Обязательные runtime sources из JSON

| ID | License | Target | Gate |
|---|---|---|---|
| `vehicle_generic_sedan` | CC BY | `assets/vehicle/generic_sedan` | Manual Sketchfab login likely; автор MMC Works обязателен в credits |
| `dashcam_case` | CC BY | `assets/vehicle/dashcam` | Manual login likely; femoldark credit |
| `diner_sushi_restaurant_kit` | CC0 | `assets/diner/quaternius_sushi_restaurant` | Primary diner/food/base NPC pack |
| `npc_feline_anthro` | CC BY | `assets/characters/feline_visitor` | Manual login likely; Turmoillion credit |
| `restroom_house_interior` | CC0 | `assets/restroom/quaternius_home_interior` | Fixtures, не готовая public restroom shell |
| `forest_kenney_nature` | CC0 | `assets/forest/kenney_nature` | Primary segmented vegetation |
| `rabbit_cc0` | CC0 | `assets/rabbit/cdmir_rabbit` | Проверить clips, axes, root motion |
| `sky_qwantani_night_puresky` | CC0 | `assets/environment/sky` | Runtime 4K/8K, 24K только source |
| `material_road012c` | CC0 | `assets/materials/road012c` | Runtime 2K |
| `material_tiles032` | CC0 | `assets/materials/tiles032` | Runtime 2K |

Обязательные правила:

- Скачивать с original page; сохранять URL, author, license, дату проверки и исходный LICENSE/README отдельно от runtime.
- Не обходить Sketchfab/Freesound login. Недоступное фиксировать в `docs/MANUAL_DOWNLOADS.md`, продолжая незаблокированную работу.
- CC BY обязательно в `ASSET_CREDITS.md`; CC0 фиксировать для provenance.
- `CC0 Toilet Paper Roll` имеет конфликт metadata: описание CC0, UI Sketchfab CC BY. При использовании считать CC BY и атрибутировать.
- Ссылка `Ultimate Food Pack` в manifest ведёт на общий Quaternius homepage; она не является достаточной точной source page. Не загружать до идентификации точной карточки.
- Unsplash/Pexels и прочие visual references не являются runtime textures.
- Перед релизом повторно проверить лицензии: manifest сам требует revalidation, а web metadata изменяемы.

## 8. Ошибки и риски шаблонов Godot 4.7

| Приоритет | Место | Проблема | Production correction |
|---|---|---|---|
| P0 | `water_stream.gdshader` | `depth_draw_alpha_prepass` — старое имя Godot 3; в Godot 4 render mode называется `depth_prepass_alpha` | Заменить и реально скомпилировать material в сцене. Официальный список: [Spatial shader render modes](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) |
| P0 | Diner meal montage | Template вызывает `_set_meal_stage()` после `await blink.blink()`, то есть после открытия глаз | Переключать stage синхронно по `full_dark`; тестировать frame capture |
| P0 | Diner F/E transition | Template грузит Restroom/Forest без обязательного blink | Persistent transition overlay должен сменить сцену во время полной темноты |
| P0 | Blink teardown | Template не освобождает `blink` lock в `_exit_tree`; scene switch во время coroutine может оставить permanent lock | Сделать overlay persistent либо гарантированный `_exit_tree` cleanup/cancel |
| P0 | Input integration | Dashcam template ловит любой `interact` глобально | Вход только через существующий ray/Area3D; global handler активен лишь в focused mode |
| P1 | Cinematic path | `PathFollow3D.loop` по умолчанию `true`; template не выключает его | Для Entry/Table/Rabbit явно `loop=false`; проверить endpoint. Документация: [PathFollow3D](https://docs.godotengine.org/es/4.x/classes/class_pathfollow3d.html) |
| P1 | GameFlow/load order | Pack GameFlow меняет state после loader return; новая сцена может выполнить `_ready()` со старым state | Передать pending target и сделать его доступным до scene ready; при failure rollback |
| P1 | Loader ready | Снятие lock сразу после `change_scene_to_packed()` не доказывает готовность новой сцены | Дождаться ready/минимум process frames и explicit scene-ready handshake |
| P1 | Lock model | Один boolean `is_locked()` не позволяет Diner path запретить movement, но разрешить local look | Разделить capability channels или добавить scoped policy per controller |
| P1 | Camera tween | Tween `Camera3D.global_transform` может конфликтовать с parent yaw/pitch/bob | Tween dedicated focus rig/weight; pause look writer; restore local rig state без drift |
| P1 | Dashcam screen types | Template `screen_root: CanvasItem`, тогда как физическая поверхность — MeshInstance3D | Разделить 3D device screen и Control compositor; screen shader получает итоговую feed texture |
| P1 | Cull layers | Template не назначает конкретные layer bits | Утвердить world/interior/helper/screen/mirror masks и runtime assert feedback exclusion |
| P1 | Rabbit one-shot | `rabbit_event_seen` ставится только в конце; выход из scene посреди event может разрешить повтор | Ставить accepted-start flag сразу; completed хранить отдельно при необходимости |
| P1 | Rabbit orientation | PathFollow loop выключен, но model-front/rotation mode/root motion не согласованы | Явно настроить `rotation_mode`, `use_model_front`, import clips и один источник translation |
| P2 | Road axis | Template двигает global positions по world axis и имеет одну длину для всех | Зафиксировать одинаковую длину/pivot или хранить per-segment length; учитывать transform root |
| P2 | Menu selection | Обычный Button с `button_pressed=true` без `toggle_mode` не гарантирует устойчивую визуальную отметку | Selected style/state отдельно; disable all; keyboard focus остаётся читаемым |
| P2 | Dashcam warp | Warped UV выходит за 0..1 и может тянуть край feed | Clamp/mask UV, border/vignette; проверить Compatibility/Forward+ gamma |
| P2 | Blink edge | Две непрозрачные polygon/Control маски без gradient дают жёсткую кромку | Gradient/feather shader или layered antialias, сохранив настоящую полную темноту |
| P2 | Sink normal | Прямая запись view-space `NORMAL` из UV-ripple даёт неверное освещение при повороте mesh | Предпочесть tangent-space `NORMAL_MAP`/normal texture, как в pack shader |

## 9. Acceptance checklist

### Preflight

- [ ] Godot сообщает ровно `4.7.stable.official.5b4e0cb0f`.
- [ ] `--headless --editor --quit` не выдаёт parser/shader/missing-resource errors Lost Signal.
- [ ] Прямо запускаются NightDrive, DinerSequence, Restroom, ForestRoad.
- [ ] Отдельно запускаются `Main.tscn` и `InfiniteRoad.tscn`.
- [ ] Зафиксирован renderer и renderer-specific visual fallback.
- [ ] Все runtime assets имеют provenance/credits; manual blockers честно перечислены.

### Run 1 — полный маршрут с туалетом

- [ ] FRONT, REAR, SPLIT и выход E/Esc.
- [ ] Заказ `Лагман`.
- [ ] Обе точные реплики кассира и `Сотрудник: Ваш заказ.`.
- [ ] Full -> Partial -> Empty только в темноте.
- [ ] F открывает отдельный Restroom.
- [ ] E у sink завершает wash; вода/audio/particles выключены.
- [ ] F возвращает в car/Forest; order/meal/restroom/washed сохранены.
- [ ] Rabbit один раз, виден MAIN и FRONT.
- [ ] DemoComplete достигнут.

### Run 2 — без туалета

- [ ] Заказ `Котлета с картофелем`.
- [ ] E после еды, F не нажат.
- [ ] После transition нет Diner Camera3D, audio и SubViewport.
- [ ] Forest использует тот же VehicleInterior.
- [ ] Rabbit один раз, DemoComplete.

### Run 3 — стресс и третий заказ

- [ ] Заказ `Яичница с колбасой`.
- [ ] Одновременные/быстрые 1/2/3 дают один selected order.
- [ ] E во время dashcam focus Tween не создаёт второй Tween/lock.
- [ ] Esc закрывает dashcam и оба feeds disabled.
- [ ] Быстрые F+E после еды запускают один transition.
- [ ] Повторные E у sink не дублируют state event.
- [ ] Принудительный повтор rabbit trigger и segment recycle дают no-op.

### Failure/teardown injection

- [ ] Invalid scene path возвращает state, снимает loader lock и оставляет управляемую текущую сцену.
- [ ] Scene unload во время blink не оставляет owner в InputLock.
- [ ] Scene unload во время sink sequence останавливает water loop/particles.
- [ ] Scene unload во время dashcam focus отключает оба SubViewport.
- [ ] Потеря optional audio не блокирует progression.
- [ ] Missing required mesh не замалчивается procedural primitive как «финальный asset».

### Performance evidence

- [ ] На RTX 3050/1080p измерены FPS и frame time отдельно в 4 сценах.
- [ ] Записаны draw calls, object count, VRAM, shadow-casting lights, active SubViewport.
- [ ] Road/forest работают минимум 3 минуты без роста nodes/resources и видимого шва.
- [ ] Вне dashcam focus и вне mirror view соответствующие SubViewport disabled.
- [ ] Нет одного гигантского forest MultiMesh AABB.
- [ ] Нет small-prop trimesh collision.

## 10. Definition of Done

Vertical slice готов только если одновременно выполнено всё ниже:

- последовательность реально запускается и полностью проходится от NightDrive до DemoComplete;
- основной маршрут и optional restroom не soft-lock'ятся;
- дорога движется сегментами, автомобиль имеет полноценный читаемый интерьер;
- dashcam имеет FRONT/REAR/SPLIT и не рендерится вне focus;
- Diner содержит четыре живые роли, два Path3D, три блюда и точные реплики;
- еда меняется через eyelid full-dark montage;
- Restroom не пустой, sink работает и teardown безопасен;
- animated rabbit естественно пересекает фары ровно один раз;
- выбранные third-party assets реально импортированы либо честно отмечены как manual blocker; blockout не назван финалом;
- Output не содержит ошибок Lost Signal, лицензии заполнены, три clean runs задокументированы;
- `Main.tscn`, player interaction, cube cutscene, door->`InfiniteRoad.tscn`, `InfiniteRoad.tscn` и fullscreen/VHS overlays не сломаны.

Если хотя бы один из этих пунктов не доказан запуском/профайлером/scene inspection, статус — `in progress`, а не `complete`.
