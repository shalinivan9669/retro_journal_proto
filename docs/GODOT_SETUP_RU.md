# Подключение Албасты в Godot 4

## 1. Сгенерировать модель

```powershell
./run_generate_albasty.ps1
```

Должен появиться файл:

```text
assets/models/albasty_lowpoly.glb
```

## 2. Скопировать в Godot-проект

Если этот пакет лежит отдельно, перенеси в корень Godot-проекта:

```text
assets/models/albasty_lowpoly.glb
scripts/albasty_controller.gd
scripts/albasty_spawn_controller.gd
scripts/horse_guard_zone.gd
scenes/albasty_instance.tscn
scenes/albasty_spawn_controller.tscn
scenes/horse_guard_zone_template.tscn
```

## 3. Группы

На лошадей поставить группу:

```text
horses
```

На игрока поставить группу:

```text
player
```

На точки появления возле ЛЭП поставить группу:

```text
albasty_spawn_points
```

Для точки появления достаточно `Marker3D`.

## 4. Сцены

Добавь на уровень:

```text
scenes/albasty_spawn_controller.tscn
```

Проверь в инспекторе:

```text
albasty_scene = res://scenes/albasty_instance.tscn
```

## 5. Игровая логика

`albasty_controller.gd` делает базовое поведение:

- ищет ближайшую ноду в группе `horses`;
- медленно идёт к ней;
- если дистанция меньше `horse_danger_radius`, кидает сигнал `reached_horse_zone`;
- если игрок слишком далеко, исчезает.

## 6. Как отгонять Албасты

Можно из фонаря/огня/ритуального предмета вызвать:

```gdscript
albasty.repel_from_position(player.global_position, 5.0)
```

## 7. Минимальный вариант без спавнера

Можно просто поставить `scenes/albasty_instance.tscn` вручную возле ЛЭП на карте.
