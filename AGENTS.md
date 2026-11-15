# 4D

Игра **4D** на **Godot 4.7** (сборка редактора 4.7.2, рендер Compatibility). Две плоскости, механики пока заглушки:

- пиксельная 2D-карта: узлы и тропинки, фишки ходят как в настолке;
- 3D-стол от первого лица для карточных боёв. Настроение как у Inscryption, свои предметы и картины, чужие ассеты оттуда не брать.

Старая арена магов (`scenes/battle/`) — наследие, в меню её нет.

## Папки

| Путь | Что там |
| --- | --- |
| `scenes/menu/` | главное меню |
| `scenes/map/` | карта |
| `scenes/table/` | стол |
| `scripts/map/`, `scripts/table/`, `scripts/menu/` | логика этих сцен |
| `scripts/autoload/journey.gd` | переход карта ↔ стол |
| `shaders/` | пост-обработка карты и стола |
| `assets/` | картинки и модели, опись в `assets/ASSETS.md` |
| `data/map.json`, `data/cards.json` | граф узлов и колоды-заглушки |
| `fonts/` | Noto Sans для русского UI |
| `.github/workflows/export.yml` | автосборка |

## Запуск и сборка

Редактор: Godot 4.7.2, не .NET. Import `project.godot`, F5. Окно называется 4D.

Windows собирает workflow **Export** на пуше в `main`, `cursor/battle-arena-prototype-e0bf` и `cursor/board-map-card-table-f041`. Релиз-пререлиз с тегом `latest` перезаписывается. Файл: [4D-windows.zip](https://github.com/danyakulakov544-ux/magicka/releases/download/latest/4D-windows.zip), внутри `4D.exe`. Рядом лежит `4D-linux.zip`.

## Правила работы

1. Сначала бесплатные ассеты **CC0**: [Kenney](https://kenney.nl/assets), [KayKit](https://kaylousberg.itch.io/), [Quaternius](https://quaternius.com/), [Poly Haven](https://polyhaven.com/), [ambientCG](https://ambientcg.com/). Генерировать только то, чего нет в этих библиотеках. Новую строку заносить в `assets/ASSETS.md`.
2. Механики и правила не писать, пока владелец не одобрит визуал.
3. На столе мышь двигает только курсор (выбор и выкладка карт). Камера — фиксированные ракурсы на WASD, с плавным возвратом. Свободного обзора нет.
4. Арену магов не возвращать в меню и не развивать.
5. Палитра стола тёмная и тёплая, без красного пересвета. Карта — пиксельный мир: узлы это предметы на тропинках, фишки это человечки.

## Брифы

Текст брифов сюда не копировать. В репозитории их нет, они у владельца в переписке к [PR #2](https://github.com/danyakulakov544-ux/magicka/pull/2):

- визуальный бриф карточного стола;
- референс пиксельной карты (тёмный лес, хижина, тропинки).
