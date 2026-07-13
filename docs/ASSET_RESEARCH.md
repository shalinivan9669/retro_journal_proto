# Lost Signal — исследование и фактический импорт ассетов

Дата проверки: **13 июля 2026 года**. Исследование выполнено по оригинальным страницам авторов; перезаливы, ripped assets, Editorial, NC и ND не использовались.

## Что было изучено

Построчно прочитаны оба приложенных `pasted-text.txt`, полный `Pasted text(1).txt` внутри ZIP и каждый файл `lost_signal_scene_pack`: README, мастер-промпт, четыре документа, JSON-манифест, 11 typed GDScript-примеров и два shader-файла. Второе внешнее вложение физически обрывается на строке «В траве появляется корот…»; недостающая часть восстановлена из полной версии внутри архива и первого вложения.

Проверен `res://_incoming_assets/`: каталога на момент аудита нет. Существующие пользовательские изменения и gameplay-файлы не трогались.

## Итог

Автоматически и законно получен рабочий CC0 payload примерно на 213 MiB: 109 моделей закусочной, 8 rigged NPC-вариантов с 30 анимациями, 329 лесных GLB, 72 дорожных GLB, анимированный заяц, 12 санитарных/дверных FBX, 7 exterior-car fallback FBX, PBR дороги/плитки/повреждений, 4K ночной HDRI и один OGG door chime. Исходные ZIP/7z сохранены отдельно в `res://assets/lost_signal/_sources/`.

Автомобиль с салоном, корпус dashcam и primary cat не скачаны: официальные страницы Sketchfab подтверждают Downloadable + CC BY, но фактическая загрузка требует авторизации. Обход входа и сторонние зеркала не использовались; точные действия находятся в `docs/MANUAL_DOWNLOADS.md`.

## Критические кандидаты

| Сцена | Объект | Кандидат | Автор | Лицензия | Формат / сложность | Текстуры / анимации | Решение |
|---|---|---|---|---|---|---|---|
| Машина | основной автомобиль | [Generic Sedan Car](https://sketchfab.com/3d-models/generic-sedan-car-58c33766470d46e7b2aed542650494e5) | MMC Works | CC BY; NoAI flag для AI-датасетов | 113.2k tris, separated parts, Rigacar | basic maps; rough interior | **Primary, manual login.** Лучший найденный бесплатный салон; не подменять exterior-only моделью. |
| Машина | fallback car | [Low-Poly Sedan car](https://sketchfab.com/3d-models/low-poly-sedan-car-aeb2699532b4402e8b75ec8888b800b9) | scailman | CC BY по manifest; страница в текущей проверке отдала anti-bot | low-poly, отдельные двери/колёса/руль | интерьер | Только если primary не импортируется; manual. |
| Машина | exterior/shadow car | [Cars Pack](https://quaternius.com/packs/cars.html) | Quaternius | CC0 | официальный page: 8 models; публичная FBX-папка сейчас содержит 7 | vertex/material colors, без полноценного салона | **Скачано.** Только дальняя машина/кузов/тень; не выдавать за primary interior. |
| Машина | dashcam case | [Dashcam case for Raspberry Pi Zero](https://sketchfab.com/3d-models/dashcam-case-for-use-with-raspberry-pi-zero-54bb760890944bcbbc47db2a7f17429c) | femoldark | CC BY | 27.6k tris | корпус, switches, LEDs, buttons | **Primary, manual login.** Экран и крепление собрать в Godot. |
| Машина | high-poly dashcam reference | [Car Dashcam](https://sketchfab.com/3d-models/car-dashcam-7718b73c67c5415fa3b4c1773fe75767) | envereren93 | CC BY по manifest | около 5M tris | детальная dual-camera форма | Отклонён для runtime; reference only. |
| Дорога | asphalt | [Road 012 C](https://ambientcg.com/view?id=Road012C) | ambientCG | CC0 | 1K–8K PBR | Color, AO, height, NormalGL/DX, Roughness | **Скачан 2K JPG.** Основной road material. |
| Дорога | damage decals | [Asphalt Damage Set 001](https://ambientcg.com/view?id=AsphaltDamageSet001) | ambientCG | CC0 | decal set | PBR + opacity | **Скачан 1K JPG.** 3–5 редких decals. |
| Дорога | modular props | [City Kit (Roads)](https://kenney.nl/assets/city-kit-roads) | Kenney | CC0 | 70 advertised files; 72 GLB в текущем ZIP | общий colormap | **Скачано.** `Textures/colormap.png` восстановлен в требуемой относительной папке. |
| Дорога | alternate modules | [Modular Streets Pack](https://quaternius.com/packs/modularstreets.html) | Quaternius | CC0 | 25 FBX/OBJ/Blend | stylized colors | Проверен, не скачан: Kenney + procedural loop достаточно. |
| Небо | primary night sky | [Qwantani Night (Pure Sky)](https://polyhaven.com/a/qwantani_night_puresky) | Greg Zaal; Jarod Guest / Poly Haven | CC0 | исходник 24K; runtime EXR | unclipped HDRI, Milky Way | **Скачан 4K EXR (73.08 MB).** 24K не помещён в runtime. |
| Небо | forest fallback | [Satara Night (No Lamps)](https://polyhaven.com/a/satara_night_no_lamps) | Greg Zaal / Poly Haven | CC0 | до 16K | stars + tree silhouettes | Проверен, не скачан: Qwantani уже покрывает runtime. |
| Небо | lighting reference | [Narrow Moonlit Road](https://polyhaven.com/a/narrow_moonlit_road) | Greg Zaal / Poly Haven | CC0 | до 24K | moonlit road HDRI | Reference / optional secondary lighting, не runtime dependency. |
| Закусочная | architecture, food, staff | [Sushi Restaurant Kit](https://quaternius.com/packs/sushirestaurantkit.html) | Quaternius | CC0 | 108 advertised models; FBX/OBJ/Blend/glTF | shared palette; characters have 30 clips | **Скачано 109 self-contained glTF.** Основа diner. |
| Закусочная | extra furniture | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Kenney | CC0 | 140 files | stylized | Проверен, не скачан: дублирует Sushi/House payload. |
| Закусочная | extra food | [Food Kit](https://kenney.nl/assets/food-kit) | Kenney | CC0 | 200 files | stylized | Проверен, не скачан: Sushi уже содержит 36 food glTF. |
| Закусочная | extra food fallback | [Ultimate Food Pack](https://quaternius.com/packs/ultimatefood.html) | Quaternius | CC0 | 103 FBX/OBJ/Blend | no required animations | Проверен, не скачан; только если трёх состояний блюда нельзя собрать из Sushi. |
| NPC | cat visitor primary | [Improved Feline Anthro Character](https://sketchfab.com/3d-models/improved-feline-anthro-character-fb0fe720fdee40c1af3185b7e0df6fed) | Turmoillion | CC BY | 16.6k tris, rigged | walk/run/jump/idle | **Primary, manual login.** Требуется sitting pose; не заменять молча человеком. |
| NPC | cat fallback | [Anthro Female Cat Base](https://sketchfab.com/3d-models/anthro-female-cat-base-6aa428b9844d47ef9cac635c9b7bec14) | автор страницы | CC BY по manifest | rigged/UV | facial shape keys, no locomotion | Страница сейчас блокируется anti-bot; fallback only. |
| NPC | cashier/server/visitor | Panda + Rabbit variants from Sushi Kit | Quaternius | CC0 | 2–3 meshes, 1 skin each | **30 clips:** Idle, Sitting_Idle, Sitting_Eating, Walk, Run, Wave и др. | **Скачано.** Panda и 7 visual Rabbit variants. |
| Туалет | fixtures | [Ultimate House Interior Pack](https://quaternius.com/packs/ultimatehomeinterior.html) | Quaternius | CC0 | 123 advertised models, FBX/OBJ/Blend | vertex/material colors | **Скачана целевая выборка:** 11 bathroom FBX + Door_1. |
| Туалет | hero paper roll | [CC0 Toilet Paper Roll](https://sketchfab.com/3d-models/cc0-toilet-paper-roll-6d5284b842434413a17133f7bf259669) | plaggy | описание CC0, UI Sketchfab CC BY | 456 tris, 4K PBR | multiple formats | Отклонён: конфликт метаданных и лишние 4K; Quaternius paper уже есть. |
| Туалет | hanging lamp | [Modern Ceiling Lamp 01](https://polyhaven.com/a/modern_ceiling_lamp_01) | James Ray Cock / Poly Haven | CC0 | 6k tris, glTF/FBX | до 8K | Проверен; не нужен для fluorescent-panel постановки. |
| Туалет | wall tile | [Tiles 032](https://ambientcg.com/view?id=Tiles032) | ambientCG | CC0 | 1K–8K PBR | dark green glossy subway tile | **Скачан 2K JPG.** |
| Туалет | proposed floor tile | `Tiles141` из scene pack | ambientCG | предполагался CC0 | страница `?id=Tiles141` не открывается; поиск не находит такой asset | неизвестно | **Отклонён как недействующая ссылка.** Не подменялся случайной текстурой. |
| Лес | primary vegetation | [Nature Kit](https://kenney.nl/assets/nature-kit) | Kenney | CC0 | 330 advertised files; 329 GLB в ZIP | self-contained GLB | **Скачано.** MultiMesh source; ближние модели требуют night material pass. |
| Лес | secondary vegetation | [150+ LowPoly Nature Models](https://quaternius.itch.io/150-lowpoly-nature-models) | Quaternius | CC0 | 150 FBX/OBJ/Blend, 21 MB | stylized | Проверен, не скачан: текущих Kenney + уже имеющихся Poly Haven растений достаточно. |
| Лес | rabbit primary | [Rabbit](https://opengameart.org/content/rabbit-0) | CDmir; TinyWorlds | CC0 | FBX/Blend, rigged | diffuse, normal; Basic/Dead/Dying/Guard/Jump/Running/Sitting clips | **Скачано.** Primary crossing actor. |
| Лес | rabbit fallback | [Low-poly animated rabbit](https://sketchfab.com/3d-models/low-poly-animated-rabbit-dcf4d25f535347b1bfb859c659314bde) | Pneshik | CC BY | 856 tris | rigged, textures, 5 animations | Проверен; не скачан, primary уже доступен. |
| Лес | motion reference | [Animalia — European Rabbit](https://sketchfab.com/3d-models/animalia-european-rabbit-6f2a3abee4de42ceb09ab48b4131517c) | GamesInMotion | нет свободной full download license | 2.1k preview; paid/full product | 66 animations only in product | **Reference only; не скачивать.** |

## Фактически загруженные файлы

| Payload | Runtime путь | Количество / размер | Исходник |
|---|---|---:|---|
| Quaternius Sushi Restaurant | `res://assets/lost_signal/diner/quaternius_sushi_restaurant/` | 109 glTF + 2 PNG, ~25 MiB | public Google Drive linked from official page |
| Quaternius House Interior subset | `res://assets/lost_signal/restroom/quaternius_house_interior/` | 12 FBX + license, 254,076 B | public Google Drive linked from official page |
| Quaternius Cars fallback | `res://assets/lost_signal/vehicle/quaternius_cars/` | 7 FBX + license, 537,552 B | public Google Drive linked from official page |
| Kenney Nature Kit | `res://assets/lost_signal/forest/kenney_nature/` | 329 GLB + license/preview, ~3.05 MiB | official ZIP retained |
| Kenney City Roads | `res://assets/lost_signal/road/kenney_city_roads/` | 72 GLB + texture/license, ~1.06 MiB | official ZIP retained |
| CDmir Rabbit | `res://assets/lost_signal/rabbit/cdmir_rabbit/` | FBX + 3 PNG + license, ~5.99 MiB | official OpenGameArt 7z retained |
| Qwantani Pure Sky | `res://assets/lost_signal/environment/sky/` | one 4K EXR, 73,075,343 B | official Poly Haven CDN |
| ambientCG materials | `res://assets/lost_signal/materials/` | 23 runtime files, ~44.26 MiB | three official archives retained |
| BigSoundBank chime | `res://assets/lost_signal/audio/diner/` | one OGG, 44,705 B | official direct OGG |

Полные hashes и источник каждого каталога записаны в `res://assets/lost_signal/SOURCES.md`.

## Проверка зависимостей

- 109 Sushi glTF валидны как glTF 2.0; buffers и images embedded, внешних URI нет.
- Panda и все семь Rabbit NPC имеют по 30 animation clips, включая `Idle`, `Sitting_Idle`, `Sitting_Eating`, `Walk`, `Run`, `Wave`.
- 401 Kenney GLB успешно разобраны. Nature self-contained. Все 72 City Roads GLB используют один внешний `Textures/colormap.png`; он перенесён из официального ZIP и существует по ожидаемому пути.
- Rabbit FBX ожидает `texture/Fur-skin.png`, `texture/rabbit-NORM.png`, `texture/rabbit-skinn.png`; все присутствуют.
- EXR, ZIP, 7z, PNG, FBX и OGG проверены по magic/размеру; 7z прошёл integrity test.

## Аудит уже существующих ресурсов

- `res://assets/polyhaven/processed/` уже содержит 1K foliage, rocks, bushes и trees. Малые `grass_medium_02`, `flower_*`, `wild_rooibos_bush` можно переиспользовать в hero-зоне; `island_tree_02/03` и `searsia_*` весят десятки MiB каждый и хуже подходят для массового MultiMesh.
- `res://assets/textures/sky/overcast_soil_puresky_16k.exr` весит около 984 MiB и не соответствует звёздной ночи. Не использовать как Lost Signal runtime sky.
- В проекте есть Poly Haven tables, cart, ceiling fan, rocks, plants и electronics. Они могут дать отдельные hero props, но их нельзя массово дублировать поверх лёгких Quaternius/Kenney наборов.
- Существующие radio wind/electrical-hum WAV могут быть технически переиспользованы только если подтверждено внутреннее происхождение; они не записаны как сторонние Lost Signal assets.
- `res://assets/models/props/lowpoly_power_pylon_no_wires.stl` потенциально подходит для дальнего roadside prop, но происхождение и материал следует подтвердить до включения в credits.

## Лицензионные и технические ограничения

- CC0 позволяет коммерческое использование без обязательной атрибуции; provenance всё равно сохранён в `ASSET_CREDITS.md`.
- Ни один CC BY Sketchfab-файл автоматически не скачан. После ручной загрузки обязательны автор, название, URL, лицензия и отметка изменений.
- Freesound показывает точные CC0-лицензии, но все выбранные оригиналы требуют `Login to download`; публичные preview-файлы не использованы как обход.
- `restaurant ambience` Artiom_Constantinov — CC0, но оригинал 29:25 / 484.9 MB. Для runtime разумнее вручную получить 14.7 MB CC0 fallback SpyrosPolitis и сделать короткий спокойный loop.
- Страница `Tiles141` из манифеста недействительна на дату проверки. Подмена не выполнялась.
- Корневой `.gitignore` сейчас игнорирует `*.exr`, `*.glb`, `*.gltf` и `*.fbx`. Payload существует и импортируется локально, но без scoped unignore/Git LFS не попадёт в чистый checkout. Это обязательный release gate до коммита сцен, использующих `res://assets/lost_signal/`.
- Яркие low-poly palette assets требуют единого night art pass: сниженная saturation, PBR крупных поверхностей, roughness variation, холодный ambient, white neon, туман и ограниченные динамические тени.
