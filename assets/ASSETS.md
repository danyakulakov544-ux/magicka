# Опись ассетов 4D

Всё, что уже лежит в репозитории. Новое сюда же, до коммита. Статус «в прототипе» значит: файл в сборке, отдельной приёмки владельца по каждому файлу не было.

Колонки **seed** и **рецепт** — для сгенерированных портретов и картинок. Для чужих файлов ставьте «—». Портрет без seed и рецепта не добавлять.

| Файл или папка | Источник | Лицензия | Кто добавил | Статус | seed | Рецепт |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/kenney/tiny_town/` | [Tiny Town](https://kenney.nl/assets/tiny-town) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/pieces/` | [Board Game Pack](https://kenney.nl/assets/board-game-pack), фишки | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/icons/` | [Board Game Icons](https://kenney.nl/assets/board-game-icons) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/dice/` | [Board Game Pack](https://kenney.nl/assets/board-game-pack), кости | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/graveyard/` | [Graveyard Kit](https://kenney.nl/assets/graveyard-kit): свеча, чаша, кубок, смотритель, фонарь | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/furniture/books.glb` | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/food/` | [Food Kit](https://kenney.nl/assets/food-kit): миска, кружка | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/pirate/chest.glb` | [Pirate Kit](https://kenney.nl/assets/pirate-kit) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/polyhaven/wood_diff.jpg`, `wood_nor.jpg`, `wood_rough.jpg` | [wood_table_001](https://polyhaven.com/a/wood_table_001), Dimitrios Savva, Rico Cilliers | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/polyhaven/fireplace_1k.hdr` | [fireplace](https://polyhaven.com/a/fireplace), только тёмный ambient | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/polyhaven/rogland_clear_night_1k.hdr` | [rogland_clear_night](https://polyhaven.com/a/rogland_clear_night) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kaykit/Knight.glb` | [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers), зеркало [GitHub](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0). Клипы Idle и Sit_Chair_Idle уже внутри файла | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kaykit/Mage.glb` | тот же пак Adventurers | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kaykit/Skeleton_Warrior.glb` | [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons), зеркало [GitHub](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/Crown.glb` | [Crown](https://poly.pizza/m/i0PZVuVlYv), Quaternius, файл из зеркала [quaternius-showcase](https://github.com/trebeljahr/quaternius-showcase) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/Chest_Open.glb` | Quaternius, [сундук на Poly Pizza](https://poly.pizza/m/vXaxy7ortM) не открылся (403); взят Chest_Open из того же CC0-пака | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/Coin.glb`, `Gold_Ingots.glb` | Quaternius CC0, [монета](https://poly.pizza/m/3jRhAgbc6t) и [слитки](https://poly.pizza/m/pTZyPTMH88); файлы из того же зеркала | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/bear.glb` | Sketchfab CC-BY и Poly Pizza не скачались (401 и 403). В сборке [Low Poly Bear](https://grab3d.com/models/animals/low-poly-bear/) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/survival/workbench-anvil.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/portraits/heroes/` | временные круги с голов этих же моделей | своё | агент, PR #2 | в прототипе | нет случайности | `tools/render_portraits.gd`: камера на голову, круг и цветная обводка. Файлы можно заменить |
| `fonts/NotoSans-Regular.ttf` | [Noto Sans](https://fonts.google.com/noto/specimen/Noto+Sans), текст лицензии в `fonts/NotoSans-OFL.txt` | OFL 1.1 | начальный коммит | в прототипе | — | — |
| `assets/generated/cards/` | нет подходящего CC0-портрета колоды | своё | агент, PR #2 | в прототипе | `index * 17 + ord(колода[0])`, шум бумаги | `tools/gen_art.py`: рамка колоды, силуэт, стоимость, атака, здоровье |
| `assets/generated/card_back.png` | нет подходящей рубашки CC0 | своё | агент, PR #2 | в прототипе | `3` | `tools/gen_art.py`, `card_back`: круг, ромб, четыре точки |
| `assets/generated/map/hero_0.png` … `hero_3.png` | нет человечка нужного размера в CC0-паке | своё | агент, PR #2 | в прототипе | нет случайности | `tools/build_world.py`, `hero()`: 16×16, рубашка синяя, красная, зелёная, жёлтая, ×2 nearest |
| `assets/generated/map/obj_*.png` | собрано из Tiny Town, где одного тайла не хватило | своё, тайлы CC0 | агент, PR #2 | в прототипе | — | `tools/build_world.py`: хижина, лавка, сундук, колодец, костёр, меч, тёмная хижина |
| `assets/generated/map_bg.png` | деревья Tiny Town на своём грунте | своё + CC0 | агент, PR #2 | в прототипе | `Random(4)` | `tools/build_world.py`, `build()`: ночь, тропинки по `data/map.json`, лес по краям |
| `assets/generated/flame.png` | нет языка пламени с альфой в взятых паках | своё | агент, PR #2 | в прототипе | нет случайности | `tools/gen_art.py`, `flame`: вертикальный градиент огня |
| `assets/generated/fog.png` | — | своё | агент, PR #2 | в прототипе | нет случайности | `tools/gen_art.py`, `fog_blob`: радиальный альфа-круг |
| `assets/generated/shard.png` | — | своё | агент, PR #2 | в прототипе | нет случайности | `tools/gen_art.py`, `shard`: четырёхугольник осколка |
| `assets/generated/slot_mark.png` | — | своё | агент, PR #2 | в прототипе | нет случайности | `tools/gen_art.py`, `slot_mark`: ромб и кольцо, не след лапы |
| `assets/generated/digits.png` | — | своё | агент, PR #2 | в прототипе | нет случайности | `tools/gen_art.py`, `save_digits`: битовая сетка 0–9, масштаб 4 |
