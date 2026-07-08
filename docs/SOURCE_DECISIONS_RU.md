# Решения по shader-ссылкам

## Использовать сейчас

1. Glitch Double Vision
   - использовать как fullscreen CanvasLayer overlay при приближении к TV/radio.
   - не ставить как material на 3D mesh.

2. Sandstorm Fog
   - использовать как FogVolume снаружи юрты.
   - не включать сразу на всю сцену.

3. Panoramic Sky with Clouds
   - использовать только как альтернативный sky preset.
   - не заменять текущую cloud system без теста.

4. Industrial Smoke
   - использовать позже, когда есть заводские трубы.
   - на ЛЭП не ставить.

5. Light Flare Ring
   - можно поставить один в подвал как аномалию.

6. Waving Cloth
   - только для ALBASY hair/rags/cloth.

## Отложить

1. Outline/posterization/dithering
   - fullscreen effect, опасен для всей сцены.
   - сначала нужен нормальный свет/материалы.

2. Aurora sky
   - слишком фэнтезийный риск.
   - можно позже как редкий nightmare-state.

3. Blend ORM materials
   - требует vertex color и PBR/ORM textures.
   - без подготовки мешей эффекта почти не будет.

4. Blood spray particles
   - нужен отдельный GPUParticles3D setup, cone mesh и blood texture.
   - есть только контроллер включения/выключения.
