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
| `assets/opponents/human_king.glb` | [Grab3D Winter King](https://grab3d.com/models/characters/king/). CC0, основа сгенерирована ИИ (Meshy), затем почищена в Blender. В игре 24 000 треугольников, текстуры 2048 | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/opponents/mage_king.glb` | [Grab3D Wizard](https://grab3d.com/models/characters/wizard/). CC0, AI-основа. В игре 24 000 треугольников, текстуры 2048 | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/opponents/bear.glb` | [Grab3D Brown Bear](https://grab3d.com/models/animals/bear/). CC0, AI-основа. В игре 24 000 треугольников, текстуры 2048 | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/opponents/undead_king.glb` | [Undead Mage](https://opengameart.org/content/undead-mage), Dmitry.Porotnikov. FBX и PBR-текстуры собраны в GLB, 15 082 треугольника | CC-BY 3.0 | агент, PR #2 | в прототипе | — | — |
| `assets/sky/space_lightblue.jpg`, `assets/sky/space_red.jpg` | [Space Skyboxes](https://opengameart.org/content/space-skyboxes-0), StumpyStrust, наборы light blue и red, собраны в панорамы 2048×1024 | CC0 | агент, PR #2 | в прототипе | — | — |
| `shaders/nebula_sky.gdshader` | адаптирован из [Nebula Stars Clouds](https://godotshaders.com/shader/nebula-stars-clouds/), grimbeef: дрейф, сдвиг цвета, мерцание звёзд, поверх панорам | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/Chest_Open.glb` | Quaternius, [сундук на Poly Pizza](https://poly.pizza/m/vXaxy7ortM) не открылся (403); взят Chest_Open из того же CC0-пака | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/quaternius/Coin.glb`, `Gold_Ingots.glb` | Quaternius CC0, [монета](https://poly.pizza/m/3jRhAgbc6t) и [слитки](https://poly.pizza/m/pTZyPTMH88); файлы из того же зеркала | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/kenney/survival/workbench-anvil.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit) | CC0 | агент, PR #2 | в прототипе | — | — |
| `assets/portraits/heroes/` | рендер голов `assets/opponents/` | своё | агент, PR #2 | в прототипе | нет случайности | `tools/render_portraits.gd`: камера на лицо, круг и цветная обводка. Файлы можно заменить |
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
