# PROMPT ДЛЯ CODEX: установить Retro Contamination VFX Pack в Godot 4.7 проект

Проект: `retro_journal_proto`, Godot 4.7, Forward Plus.

У меня есть архив `retro_contamination_vfx_pack.zip`. Его нужно интегрировать аккуратно, без ломания геймплея.

## 1. Распаковать файлы

Скопируй содержимое архива в корень проекта, сохранив пути:

```text
scripts/vfx/rcv_target_vfx.gd
scripts/vfx/rcv_scene_auto_installer.gd
scripts/vfx/rcv_manual_attach.gd
shaders/postprocess/rcv_bed_dream_noise.gdshader
shaders/postprocess/rcv_tv_glitch_heavy.gdshader
shaders/postprocess/rcv_radiation_field_screen.gdshader
shaders/spatial/rcv_corrosion_overlay.gdshader
shaders/spatial/rcv_ion_particle_unshaded.gdshader
shaders/spatial/rcv_bed_veil_sheet.gdshader
materials/postprocess/mat_rcv_bed_dream_noise.tres
materials/postprocess/mat_rcv_tv_glitch_heavy.tres
materials/postprocess/mat_rcv_radiation_field_screen.tres
materials/vfx/mat_rcv_corrosion_overlay.tres
materials/vfx/mat_rcv_ion_particle_unshaded.tres
materials/vfx/mat_rcv_ion_particle_white.tres
materials/vfx/mat_rcv_bed_veil_sheet.tres
scenes/vfx/RetroContaminationVFXRuntime.tscn
assets/vfx/*.png
```

## 2. Добавить runtime в Main.tscn

В `scenes/Main.tscn` уже есть основной `VisualEffectsRuntime`. Не удаляй его.
Добавь новый отдельный runtime рядом с ним.

В верхний список ресурсов добавь:

```text
[ext_resource type="PackedScene" path="res://scenes/vfx/RetroContaminationVFXRuntime.tscn" id="99_rcv"]
```

Если id занят, выбери свободный.

Внутрь корневого `[node name="Main" type="Node3D"]` добавь:

```text
[node name="RetroContaminationVFXRuntime" parent="." instance=ExtResource("99_rcv")]
auto_install_on_ready = true
install_bed_dream = true
install_tv_glitch = true
install_lep_effects = true
max_beds = 4
max_tvs = 3
max_leps = 12
bed_distance = 3.4
tv_distance = 3.0
lep_distance = 7.5
```

## 3. Проверить имена/группы объектов

Автоинсталлер ищет:

- кровать: `bed`, `mattress`, `pillow`, `blanket`, `cot`, `sleep`, `krovat`, `кровать`, `матрас`, `подушка`;
- телевизор: `interactabletv`, `tv`, `television`, `screen`, `monitor`, `crt`, `телевизор`, `экран`;
- ЛЭП: `lep`, `лэп`, `powerline`, `power_line`, `power-pole`, `transmission`, `electric_pole`, `pylon`, `tower_lep`.

Если конкретные ЛЭП называются иначе, добавь им группы:

```text
vfx_lep_radiation
vfx_lep_rust
vfx_lep_ion
```

Если кровать называется иначе, добавь группу:

```text
vfx_bed_dream
```

Если телевизор называется иначе, добавь группу:

```text
vfx_tv_glitch
```

## 4. Обязательная проверка запуска

Запусти проект в Godot 4.7 и проверь ошибки в Output.

Если Godot ругается на конкретное имя свойства ParticleProcessMaterial, исправь точечно под актуальное имя свойства Godot 4.7, не переписывая архитектуру.

## 5. Визуальное поведение, которое нужно получить

### Кровать

При приближении к кровати экран становится бело-чёрным, будто чистый ангельский сон, но не уютный: холодный, почти медицинский. Над кроватью мягкая белая пыль/вуаль.

### Телевизор

При приближении к телевизору экран сильно глитчит: RGB split, разрывы строк, scanlines, статический шум, короткие провалы яркости. Это должно быть сильнее старого мягкого glitch overlay.

### Три белые ЛЭП на карте

Развести эффекты по трём типам:

1. первая ЛЭП — радиация: янтарные ионные частицы, радиальный экранный фон, лёгкая ржавчина;
2. вторая ЛЭП — ржавчина: коррозия/соль/тёмно-оранжевая пыль без сильного screen overlay;
3. третья ЛЭП — белый ионный мёртвый ореол: холодные белые частицы, солевая/пепельная грязь, слабый свет.

## 6. Не делать

- Не удалять существующий `VisualEffectsRuntime`.
- Не ломать управление, интерактивы, радио, телевизор, подвал, окно и облака.
- Не ставить тяжёлые внешние аддоны.
- Не делать зелёную мультяшную радиацию.
- Не коммитить большие бинарники без необходимости.

## 7. После интеграции

Сделай короткий отчёт:

- какие файлы добавлены;
- куда вставлен runtime;
- какие объекты были найдены автоматически;
- если какие-то объекты не найдены — какие группы надо добавить вручную.
