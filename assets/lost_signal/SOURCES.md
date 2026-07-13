# Lost Signal asset sources

Проверено 13 июля 2026 года. Все файлы получены только с оригинальных страниц авторов или из публичных папок, на которые ведут эти страницы. Каталог `_sources/` закрыт `.gdignore`: исходные архивы хранятся для воспроизводимости, но не участвуют в runtime-импорте Godot.

## Runtime-наборы

| Каталог | Ассет | Автор | Лицензия | Оригинальная страница | Что сохранено |
|---|---|---|---|---|---|
| `diner/quaternius_sushi_restaurant/` | Sushi Restaurant Kit | Quaternius | CC0 1.0 | https://quaternius.com/packs/sushirestaurantkit.html | 109 self-contained glTF, 2 atlas PNG; среди них Panda и 7 Rabbit-вариантов с rig и 30 clips |
| `restroom/quaternius_house_interior/` | Ultimate House Interior Pack | Quaternius | CC0 1.0 | https://quaternius.com/packs/ultimatehomeinterior.html | 11 bathroom FBX + Door_1 FBX + оригинальный license text |
| `vehicle/quaternius_cars/` | Cars Pack | Quaternius | CC0 1.0 | https://quaternius.com/packs/cars.html | 7 FBX из текущей публичной папки + оригинальный license text; только exterior/fallback, не основной салон |
| `forest/kenney_nature/` | Nature Kit | Kenney | CC0 1.0 | https://kenney.nl/assets/nature-kit | 329 GLB, preview, License.txt |
| `road/kenney_city_roads/` | City Kit (Roads) | Kenney | CC0 1.0 | https://kenney.nl/assets/city-kit-roads | 72 GLB, обязательный `Textures/colormap.png`, License.txt |
| `rabbit/cdmir_rabbit/` | Rabbit | CDmir; collaborator TinyWorlds | CC0 1.0 | https://opengameart.org/content/rabbit-0 | FBX, 3 PNG textures, original License.txt; clips include Running and Jump |
| `environment/sky/` | Qwantani Night (Pure Sky) | Greg Zaal; processing Jarod Guest / Poly Haven | CC0 1.0 | https://polyhaven.com/a/qwantani_night_puresky | 4K EXR, not the 24K source |
| `materials/road012c/` | Road 012 C | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Road012C | 2K JPG PBR maps, preview and Godot `.tres` |
| `materials/tiles032/` | Tiles 032 | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=Tiles032 | 2K JPG PBR maps, preview and Godot `.tres` |
| `materials/asphalt_damage/` | Asphalt Damage Set 001 | ambientCG | CC0 1.0 | https://ambientcg.com/view?id=AsphaltDamageSet001 | 1K JPG decal maps, preview and Godot `.tres` |
| `audio/diner/` | Shop doorbell chime #3588 | Joseph SARDIN / BigSoundBank | CC0 | https://bigsoundbank.com/shop-doorbell-chime-s3588.html | Original public OGG, 48 kHz source offered by author |

CC0 legal reference: https://creativecommons.org/publicdomain/zero/1.0/

## Preserved source archives

| File | Bytes | SHA-256 |
|---|---:|---|
| `AsphaltDamageSet001_1K-JPG.zip` | 5,052,524 | `1BE7C8C6BEB2D8C56E5FC360B7EB0715E2FA1FA119FFA7B4CCC3E0F411776AD2` |
| `kenney_city-kit-roads.zip` | 1,716,227 | `2C1644A293A85D98837EF788B0CBC4B9D53DFFB1280FBE9A4F927B644AABA4B0` |
| `kenney_nature-kit.zip` | 10,537,521 | `FA7974A0D342BFE63C38664BA9F8EC1A4AAB8EA25F099BDC56870E33588C4D9D` |
| `rabbit-FBX.7z` | 4,413,478 | `DACAE75ED379BE049D7AB79EE228454F47333B91C2F023DF4B969F3B1CF97715` |
| `Road012C_2K-JPG.zip` | 34,358,401 | `23CAC85F18D619F6AE172883BCA92CDEFE5AB5880CE0E3FCB89958C7510732ED` |
| `Tiles032_2K-JPG.zip` | 10,343,545 | `6C37A3ECCE5DDEE62E19CF17ECE3EABF90B5BED38774967B773F37B06CA7F8C1` |

Google Drive — официальный способ распространения Quaternius на его страницах. Эти наборы состоят из отдельных публичных файлов, поэтому нового неофициального архива для них не создавалось.

## Integrity notes

- `qwantani_night_puresky_4k.exr`: 73,075,343 bytes; OpenEXR magic `76 2F 31 01`; SHA-256 `E9044D6A2F6EE25175786C1D72179861520FD4769A7E873D40B1299C7B6DA476`.
- `shop_doorbell_chime_3588.ogg`: 44,705 bytes; Ogg magic `OggS`; SHA-256 `4541D40F527051373560C8694DED96AF9BBA8516521A6FF04311AC79B1CA50A4`.
- Все 109 Sushi glTF разобраны как glTF 2.0 JSON; внешних buffer/image URI нет.
- Все 401 Kenney GLB разобраны без ошибок. 72 City Roads GLB ссылаются на `Textures/colormap.png`; файл присутствует. Nature GLB self-contained.
- Rabbit FBX ссылается на три относительных `texture/*.png`; все три файла присутствуют.

