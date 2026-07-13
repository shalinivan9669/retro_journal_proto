# Lost Signal — визуальные референсы и применённый art direction

Проверено 13 июля 2026 года. Референсы используются для композиции, света и материалов; фотографии и preview-изображения не копировались в runtime.

## Ночная дорога и салон

- [Qwantani Night (Pure Sky)](https://polyhaven.com/a/qwantani_night_puresky) — читаемый Млечный Путь над почти чёрным горизонтом. В runtime используется официальный 4K EXR, не 24K source.
- [Narrow Moonlit Road](https://polyhaven.com/a/narrow_moonlit_road) — узкий холодный коридор фар и подавленные обочины.
- [Generic Sedan Car](https://sketchfab.com/3d-models/generic-sedan-car-58c33766470d46e7b2aed542650494e5) — положение водительской камеры, стоек и приборов; asset остаётся ручной загрузкой.
- [Car Dashcam](https://sketchfab.com/3d-models/car-dashcam-7718b73c67c5415fa3b4c1773fe75767) — только пропорции устройства; 5M-tris кандидат не импортировался.

Применено: почти чёрный салон, бирюзовая приборная подсветка, два физических SpotLight3D и центральный fill, PBR Road012C, статичное звёздное небо, ограниченный обзор и низкоамплитудная вибрация без random jitter.

## Закусочная

- [Sushi Restaurant Kit](https://quaternius.com/packs/sushirestaurantkit.html) — функциональная стойка, мебель, еда и анимированные антропоморфные роли.
- [Roadside diner night — Unsplash search](https://unsplash.com/s/photos/roadside-diner-night) — белый фасадный свет против тёмной парковки.
- [Diner interior — Pexels search](https://www.pexels.com/search/diner/) — booths, цветовая полоса стен, локальный тёплый свет у кассы.

Применено: холодно-белый фасад, тёплая касса, клетчатый пол, тёмно-красные booths, Quaternius tables/props/animated Panda/Rabbits, несинхронные idle offsets, меню в тёмном ночном стиле. Яркая исходная mobile-палитра приглушена светом и material overrides.

## Туалет

- [Tiles 032](https://ambientcg.com/view?id=Tiles032) — основной серо-зелёный PBR subway tile.
- [Public restroom — Pexels search](https://www.pexels.com/search/public%20restroom/) — две раковины, зеркало, кабинки и отдельный технический угол.
- [Poly Haven Bathroom](https://polyhaven.com/a/bathroom) — холодные отражения сантехники и локальные мокрые блики.

Применено: Tiles032 2K без дорогого runtime heightmap, холодные панели, локальные лужи, Quaternius sinks/toilets, трубы/швабра/ведро/химия рядом с техническим шкафом, зеркало 512×512 с управляемым update.

## Лес и заяц

- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) — лёгкая сегментная растительность и вариативные силуэты.
- [Rabbit by CDmir/TinyWorlds](https://opengameart.org/content/rabbit-0) — выбранная rigged-модель и клип `Armature|Running`.
- [Satara Night (No Lamps)](https://polyhaven.com/a/satara_night_no_lamps) — плотные кроны, скрывающие часть звёзд.

Применено: видимый лесной коридор вместо огромного мира, Kenney meshes в отдельных MultiMesh каждого дорожного сегмента, ближние деревья для фар, более плотный fog, короткий rustle и естественное пересечение без stinger, крови или столкновения.

## Единые ограничения стиля

- Основные поверхности используют приглушённые цвета, variation roughness и максимум один shadow-casting key light на сцену.
- Compatibility renderer не поддерживает volumetric fog/Decal так же, как Forward+; применены depth fog, PBR-материалы, геометрические wet patches и emissive accents.
- Прозрачность ограничена стеклом, водой, зеркалом и локальными мокрыми пятнами.
- Большинство runtime textures 1K–2K; единственное крупное окружение — 4K HDRI.
