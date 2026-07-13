# Retro Contamination VFX Pack для Godot 4.7

## Текущий запуск проекта: Lost Signal

Обычный запуск проекта теперь начинает новую последовательность:

`ночная трасса → закусочная → заказ и еда → необязательный туалет → лес → заяц → Main.tscn`.

Стартовая сцена: `res://scenes/lost_signal/road/NightDrive.tscn`.

Запуск: `RUN_LOST_SIGNAL_DEMO.bat` или стандартная команда Godot с `--path` на корень проекта. После финальной карточки старая `res://scenes/Main.tscn` загружается автоматически; `E` ускоряет переход.

Пакет даёт готовую систему эффектов для `retro_journal_proto`:

- кровать: бело-чёрный шум, холодный сон, мягкая белая пыль/вуаль;
- телевизор: тяжёлый CRT/glitch/postprocess, разрыв строк, RGB split, статический шум;
- ЛЭП/белые опоры: три варианта — радиация, ржавчина, белый ионный мёртвый ореол;
- дополнительный вариант: dead signal — слабый радио/ТВ-паразитный эффект для любой опоры.

Пакет не требует внешних аддонов. Всё процедурное: GDScript + `.gdshader` + несколько служебных PNG-масок.

## Быстрая установка

1. Скопировать папки из архива в корень проекта Godot:

```text
scripts/vfx
shaders/postprocess
shaders/spatial
materials/postprocess
materials/vfx
scenes/vfx
assets/vfx
```

2. Открыть `scenes/Main.tscn`.

3. Добавить resource в верхнюю часть файла рядом с другими `ext_resource`:

```text
[ext_resource type="PackedScene" path="res://scenes/vfx/RetroContaminationVFXRuntime.tscn" id="99_rcv"]
```

4. Добавить node внутрь корневого `Main`:

```text
[node name="RetroContaminationVFXRuntime" parent="." instance=ExtResource("99_rcv")]
auto_install_on_ready = true
install_bed_dream = true
install_tv_glitch = true
install_lep_effects = true
```

Если ID `99_rcv` занят, выбрать любой свободный id.

## Как система ищет объекты

Автосканер ищет объекты по именам:

- кровать: `bed`, `mattress`, `pillow`, `blanket`, `cot`, `sleep`, `krovat`, `кровать`, `матрас`, `подушка`;
- телевизор: `InteractableTV`, `tv`, `television`, `screen`, `monitor`, `crt`, `телевизор`, `экран`;
- ЛЭП: `lep`, `лэп`, `powerline`, `power_line`, `power-pole`, `transmission`, `electric_pole`, `pylon`, `tower_lep`.

Если имена в твоей сцене другие, не переименовывай всё подряд. Лучше добавь нужным объектам группы:

```text
vfx_bed_dream
vfx_tv_glitch
vfx_lep_radiation
vfx_lep_rust
vfx_lep_ion
vfx_lep_dead_signal
```

## Ручное навешивание

Если надо точно повесить эффект на конкретный объект:

1. Добавь к объекту child `Node3D`.
2. Повесь на child скрипт:

```text
res://scripts/vfx/rcv_manual_attach.gd
```

3. Выбери preset:

```text
BED_DREAM
TV_GLITCH
LEP_RADIATION
LEP_RUST
LEP_ION_WHITE
LEP_DEAD_SIGNAL
```

## Настройка силы

Главные параметры в `RetroContaminationVFXRuntime.tscn`:

```text
bed_distance = 3.4
TV distance = 3.0
lep_distance = 7.5
max_beds = 4
max_tvs = 3
max_leps = 12
```

В каждом target-компоненте есть:

```text
activation_distance
screen_intensity
particle_intensity
enable_screen_overlay
enable_particles
enable_lights
enable_corrosion_overlay
```

## Важное по производительности

- Пакет рассчитан на Forward Plus.
- Экранные оверлеи включаются только рядом с объектом.
- Частицы локальные и не требуют внешних текстур.
- На слабом железе сначала уменьшить `particle_intensity`, потом `max_leps`.

## Сильная рекомендация по стилю

Не делай радиацию кислотно-зелёной. В этой игре лучше работает грязный язык: ржавчина, соль, белая пыль, приборный шум, слабое янтарное свечение, мёртвый холодный экран.
