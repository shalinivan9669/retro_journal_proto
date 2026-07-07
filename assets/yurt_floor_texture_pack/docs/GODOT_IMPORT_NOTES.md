# Подсказки для Godot 4

## Быстрый импорт
- Albedo / BaseColor: sRGB включен.
- Roughness / Height / AO / Masks: импортировать как data / linear.
- Normal: если карта окажется обычной normal map, импортировать как normal map.
- Для всех floor textures включить Repeat.

## Материал
Использовать StandardMaterial3D.
Подключить:
- Albedo Texture
- Normal Texture (если есть)
- Roughness Texture
- Height / Displacement как Heightmap (если решите использовать parallax / тесселяцию где возможно)
- AO Texture

## Реализм
- Roughness довольно высокая: 0.65–0.95 для войлока.
- Normal strength умеренная, иначе ткань станет каменной.
- UV scale разный у каждого ковра.
- Добавить небольшую вариацию rotation у отдельных ковров.
- Лучше собрать пол из нескольких mesh-плоскостей с разными материалами, а не одним giant material.

## Практика сцены
Собери отдельные меши:
- `Floor_Base`
- `Main_Rug`
- `Center_Medallion`
- `Border_Ring`
- `Seat_Mats_01..08`

У некоторых верхних ковров дай very small Y offset, например 0.002–0.008, чтобы не было z-fighting.
