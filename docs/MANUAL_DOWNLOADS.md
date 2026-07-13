# Lost Signal — ручные загрузки

Проверено 13 июля 2026 года. `res://_incoming_assets/` на момент аудита отсутствует. Создайте его только для оригинальных файлов, загруженных с указанных страниц. Не используйте перезаливы и не помещайте preview-медиа вместо оригинала.

## P0 — три обязательных Sketchfab-ассета

Sketchfab показывает модели как downloadable и публикует лицензию, но выдаёт архив только после входа. Войдите обычным способом в браузере и нажмите **Download 3D Model** на самой странице.

### 1. Generic Sedan Car

- Страница: https://sketchfab.com/3d-models/generic-sedan-car-58c33766470d46e7b2aed542650494e5
- Автор: MMC Works.
- Лицензия: Creative Commons Attribution (CC BY); страница также содержит NoAI-ограничение для AI datasets/development, не заменяющее CC BY для игрового использования.
- Ожидается: официальный Sketchfab ZIP; предпочтительно glTF/GLB либо original FBX/Blend export с textures. Страница указывает 113.2k tris, basic paint/bottom/mechanics/interior maps, rough interior, separated parts, Rigacar.
- Положить весь архив или распакованную папку в: `res://_incoming_assets/vehicle_generic_sedan/`.
- После проверки импортировать в: `res://assets/lost_signal/vehicle/generic_sedan/`.
- Credits: `Generic Sedan Car — MMC Works — CC BY — https://sketchfab.com/3d-models/generic-sedan-car-58c33766470d46e7b2aed542650494e5`; отметить изменения материалов/LOD.

### 2. Dashcam case for Raspberry Pi Zero

- Страница: https://sketchfab.com/3d-models/dashcam-case-for-use-with-raspberry-pi-zero-54bb760890944bcbbc47db2a7f17429c
- Автор: femoldark.
- Лицензия: CC BY.
- Ожидается: официальный Sketchfab ZIP, glTF/GLB/FBX с material data; 27.6k tris. Это корпус с switches, LEDs, buttons и camera, а не готовый игровой экран.
- Положить в: `res://_incoming_assets/dashcam_case/`.
- После проверки импортировать в: `res://assets/lost_signal/vehicle/dashcam/`.
- Credits: `Dashcam case for use with Raspberry Pi Zero — femoldark — CC BY — https://sketchfab.com/3d-models/dashcam-case-for-use-with-raspberry-pi-zero-54bb760890944bcbbc47db2a7f17429c`.

### 3. Improved Feline Anthro Character

- Страница: https://sketchfab.com/3d-models/improved-feline-anthro-character-fb0fe720fdee40c1af3185b7e0df6fed
- Автор: Turmoillion.
- Лицензия: CC BY.
- Ожидается: официальный Sketchfab ZIP; rigged model, 16.6k tris, walk/run/jump/idle clips и textures.
- Положить в: `res://_incoming_assets/feline_visitor/`.
- После проверки импортировать в: `res://assets/lost_signal/characters/feline_visitor/`.
- Credits: `Improved Feline Anthro Character — Turmoillion — CC BY — https://sketchfab.com/3d-models/improved-feline-anthro-character-fb0fe720fdee40c1af3185b7e0df6fed`.
- Нужна отдельная sitting pose/animation. Если facial blend shapes отсутствуют, не обещать сложную мимику.

## P1 — CC0 audio с Freesound login

Скачивайте оригиналы кнопкой **Login to download**. Не используйте публичные `*-lq.mp3/ogg` previews как обход. Сырые файлы положить в указанные `_incoming_assets` папки; runtime OGG-loop/one-shot делать отдельным производным файлом с сохранением исходника.

| Роль | Оригинальная страница | Автор | Лицензия | Ожидаемый оригинал | Целевая incoming-папка |
|---|---|---|---|---|---|
| engine loop | https://freesound.org/people/Dmitry_mansurev64/sounds/748027/ | Dmitry_mansurev64 | CC0 | OGG, 17.009 s, 396.8 KB, 48 kHz stereo | `res://_incoming_assets/audio/engine_loop/` |
| engine idle | https://freesound.org/people/mhad/sounds/390788/ | mhad | CC0 | WAV, 3.109 s, 268.5 KB, 44.1 kHz mono | `res://_incoming_assets/audio/engine_idle/` |
| diner crowd fallback | https://freesound.org/people/SpyrosPolitis/sounds/648208/ | SpyrosPolitis | CC0 | WAV, 53.525 s, 14.7 MB, 48 kHz/24-bit stereo | `res://_incoming_assets/audio/diner_ambience/` |
| dishes | https://freesound.org/people/beansqueso31/sounds/234470/ | beansqueso31 | CC0 | WAV, 3.423 s, 1.2 MB, 88.2 kHz stereo | `res://_incoming_assets/audio/dishes/` |
| cash register | https://freesound.org/people/kyles/sounds/452572/ | kyles | CC0 | WAV, 2:36.823, 21.9 MB, 48 kHz/24-bit mono | `res://_incoming_assets/audio/cash_register/` |
| electrical/neon hum | https://freesound.org/people/chungus43A/sounds/733736/ | chungus43A | CC0 | WAV, 5.454 s, 1022.8 KB, 48 kHz stereo | `res://_incoming_assets/audio/electrical_hum/` |
| running tap | https://freesound.org/people/ken788/sounds/386749/ | ken788 | CC0 | `Tap_Running.wav`, 9.446 s, 2.4 MB, 44.1 kHz | `res://_incoming_assets/audio/running_tap/` |
| forest night | https://freesound.org/people/CHRISFOPFILMS/sounds/346224/ | CHRISFOPFILMS | CC0 | WAV, 2:04.680, 22.8 MB, 48 kHz stereo | `res://_incoming_assets/audio/forest_night/` |
| crickets | https://freesound.org/people/Defelozedd94/sounds/522298/ | Defelozedd94 | CC0 | WAV, 2:49.002, 30.9 MB, 48 kHz stereo | `res://_incoming_assets/audio/crickets/` |

Основной `restaurant ambience` из исходного manifest — https://beta.freesound.org/people/Artiom_Constantinov/sounds/859329/ — подтверждён как CC0, но это WAV длительностью 29:25.609 и размером 484.9 MB. Он не рекомендуется для репозитория без предварительного осознанного выбора и последующей нарезки; 14.7 MB SpyrosPolitis выше практичнее.

Shop doorbell вручную не нужен: официальный CC0 OGG уже находится в `res://assets/lost_signal/audio/diner/shop_doorbell_chime_3588.ogg`.

## Необязательные fallback

Использовать только если primary действительно не импортируется:

- Low-Poly Sedan car — https://sketchfab.com/3d-models/low-poly-sedan-car-aeb2699532b4402e8b75ec8888b800b9 — scailman — CC BY по scene-pack manifest. Текущая страница отдала anti-bot challenge; не обходить.
- Anthro Female Cat Base — https://sketchfab.com/3d-models/anthro-female-cat-base-6aa428b9844d47ef9cac635c9b7bec14 — CC BY по scene-pack manifest. Только если primary cat недоступна.
- Low-poly animated rabbit — https://sketchfab.com/3d-models/low-poly-animated-rabbit-dcf4d25f535347b1bfb859c659314bde — Pneshik — CC BY, 856 tris, 5 animations. Не нужен сейчас: CC0 Rabbit уже скачан.

Не скачивать `Animalia — European Rabbit` как бесплатный runtime asset: Sketchfab preview не предоставляет свободную полную модель, а страница ведёт к отдельному full product.

## После появления файлов

1. Не удалять оригинальные ZIP и license/attribution files.
2. Проверить archive integrity, реальный формат, textures, rig, clips и масштаб в метрах.
3. Скопировать только нужные runtime-файлы в `res://assets/lost_signal/...`, сохранив source URL и hash.
4. Запустить Godot editor import и проверить отсутствие missing textures.
5. Добавить реально импортированные CC BY assets в `ASSET_CREDITS.md` до публикации.
6. Проверить `git check-ignore`: текущий root `.gitignore` исключает EXR/GLB/glTF/FBX, поэтому для `assets/lost_signal/**` нужен scoped unignore или Git LFS до чистого checkout-теста.
