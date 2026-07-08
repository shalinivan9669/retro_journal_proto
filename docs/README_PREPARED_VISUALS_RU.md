# Retro Journal — подготовленный visual patch, stage 1

Это не заменяет весь арт-пайплайн. Это безопасный первый слой визуала, который можно наложить на текущий Godot-проект.

## Что уже подготовлено

1. TV/radio screen emission
   - `shaders/devices/device_screen_emission.gdshader`
   - `materials/devices/mat_tv_screen_glow.tres`
   - `materials/devices/mat_radio_display_glow.tres`

2. Glitch overlay при подходе к TV/radio
   - `shaders/postprocess/glitch_double_vision_soft.gdshader`
   - `materials/postprocess/mat_glitch_double_vision_soft.tres`

3. Runtime-инсталлер визуала
   - `scenes/visuals/VisualEffectsRuntime.tscn`
   - `scripts/visuals/retro_visuals_runtime.gd`

4. Опциональный внешний туман/пыль
   - `shaders/fog/sandstorm_fog_soft.gdshader`
   - `materials/fog/mat_sandstorm_fog_soft.tres`
   - `scenes/visuals/OutdoorSandstormFogVolume.tscn`

5. Опциональный дым для будущих заводских труб
   - `shaders/fog/industrial_smoke_minimal.gdshader`
   - `materials/fog/mat_industrial_smoke.tres`
   - `scenes/visuals/IndustrialSmokeFogVolume.tscn`

6. Опциональное кровавое/грозовое небо
   - `shaders/sky/panoramic_cloud_sky_blood.gdshader`
   - `materials/sky/mat_panoramic_cloud_sky_blood.tres`
   - `scripts/visuals/sky_lightning_controller.gd`

7. Опциональное световое кольцо в подвал
   - `shaders/vfx/light_flare_ring_minimal.gdshader`
   - `materials/vfx/mat_light_flare_ring.tres`
   - `scenes/visuals/BasementFlareRing.tscn`

8. Опциональный shader для ткани/волос ALBASY
   - `shaders/characters/albasy_waving_cloth_safe.gdshader`
   - `materials/characters/mat_albasy_waving_cloth.tres`

## Как поставить быстро

1. Скопируй папки из архива в корень Godot-проекта:
   - `shaders/`
   - `materials/`
   - `scripts/`
   - `scenes/`
   - `tools/`
   - `docs/`

2. Открой `res://scenes/Main.tscn` в Godot.

3. Добавь child node через инстанс сцены:
   - нажми цепочку / Instantiate Child Scene;
   - выбери `res://scenes/visuals/VisualEffectsRuntime.tscn`;
   - сохрани Main.tscn.

4. Запусти игру.

## Что должно измениться сразу

- TV screen станет светящимся и слегка мерцающим.
- Radio display станет янтарным/красным светящимся.
- Рядом с TV/radio появятся слабые OmniLight3D.
- При подходе к screen/display ближе `0.5` включится VHS/glitch overlay.
- WorldEnvironment станет чуть более мрачным: меньше ambient, включён glow, чуть больше fog.

## Что НЕ включено автоматически

### Sandstorm/Fog

`enable_outdoor_sandstorm = false` по умолчанию. Причина: если включить сразу, туман может попасть внутрь юрты и испортить читаемость.

Чтобы включить:

- выбери `VisualEffectsRuntime`;
- включи `enable_outdoor_sandstorm`;
- подбери `sandstorm_position` и `sandstorm_size`, чтобы FogVolume был только снаружи юрты.

### Sky replacement

Новое sky не включено автоматически. В проекте уже есть своя cloud system, поэтому полная замена неба может конфликтовать.

### Industrial smoke

Готова сцена дыма, но в текущем проекте сначала нужны дальние трубы/заводские силуэты. Не ставь дым на ЛЭП — это будет выглядеть глупо.

### ALBASY cloth

Материал готов, но его надо ставить только на волосы/ленты/лохмотья ALBASY. Не на лицо и не на тело.

### Blood spray

Есть контроллер `blood_spray_toggle.gd`, но сам particle setup требует GPUParticles3D, cone mesh и blood texture. Поэтому оно не включено автоматически.

## Что отброшено на этом этапе

- Outline/posterization/dithering fullscreen shader. Он слишком опасный для всей картинки и может превратить игру в кислотную кашу.
- Aurora sky как основной sky. Он быстро выглядит как фэнтези/северное сияние, а не степь/Балхаш/техногенный хоррор.
- Blend ORM для подвала. Он требует подготовленные PBR/ORM текстуры и vertex color на мешах. Без этого будет пустая имитация.

## Если что-то сломалось

Просто удали из `Main.tscn` node:

`VisualEffectsRuntime`

Все эффекты исчезнут. Игровая логика не должна быть затронута.
