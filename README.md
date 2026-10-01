# «Улей» · модуль «Регрессия» в SkRob

Модуль обучения регрессии встроен в общий place команды **`SkRob.rbxl`** (рядом с уровнями RandomForest и кластеризации).
Путь игрока: **3D experience** (клумба) → **2D experience** (экраны второго табло) → **лор-задача** (прогноз мёда своей пасеки).
`RegressionBeeHive.rbxlx` — лёгкая песочница модуля (baseplate), собирается из тех же исходников.

## Быстрый старт
1. Открой `SkRob.rbxl` в Roblox Studio → Play (F5).
2. В Output: `Regression ИТОГО: 222/222` (автотесты ядра, только в Studio).
3. Клумба — в ≈ 66 studs от спауна (x ≈ 62, z ≈ −28; площадка `Workspace/RegressionLevel/FlowerbedAnchor`),
   пасека лор-задачи — в ≈ 60 studs по другую сторону (x ≈ 5, z ≈ 62; `…/LoreAnchor`). HUD модуля появляется только рядом с ними.
4. Отладка в Studio (командная строка, клиент): `_G.RegressionDebug.goto("2D.4")` — сразу к нужному шагу
   (`"3D.1"`…`"3D.6"`, `"2D.1"`…`"2D.7"`, `"L.0"`…`"L.5"`).

> **Team Create.** `SkRob.rbxl` в репозитории — снимок place. Чтобы не затереть работу коллег, переноси модуль в живую
> сессию через Rojo (`rojo serve default.project.json` — проект трогает только объекты регрессии, у сервисов стоит
> `$ignoreUnknownInstances`) или скопируй объекты из таблицы ниже из `SkRob.rbxl` в открытый Team Create place.

## Путь игрока и контрольные числа
| Шаг | Что делает игрок | Что проверяется |
|---|---|---|
| 3D.1–3D.2 | подходит к клумбе, протягивает нити (F у цветка, после двух — «протянуть остальные») | табло оживает: m = 0, h = 1,0, MSE = 0,566 |
| 3D.3 | ставка про квадраты → пульт «Управлять прямой»: Q/E — наклон, Shift/Ctrl — высота | квадраты e² меняются вживую |
| 3D.4–3D.5 | 5 записей (R) на одной высоте → парабола | m* = 0,33; прямая прилипает к m* |
| 3D.6 | поднимается второе табло → F «Продолжить обучение» | веха `regression_3d` |
| 2D.1 | «Показать L = n·MSE», бегунок с касательной | dL/dm = 0 ⇒ m = 3,3 / 10 = 0,33 |
| 2D.2–2D.3 | двигает прямую с m = 0,47, 5 записей (c, MSE) | MSE(0) = 42,66 … c* = 6,2; dL/dc = 0 ⇒ c = 25 − 0,47·40 |
| 2D.4 | крутит облако 15 точек, ставка, «на 5 / на 15», карточки точек | b = (14,31; −9,16); R²: 0,981 / 0,144 / 0,900 |
| 2D.5 | ползунок λ для L2 (круг) и L1 (ромб) | L2 λ=1 → (3,22; 1,46); L1 λ ≥ 1,49 → (5,16; 0); L2 λ=20 → (0,90; 0,81) |
| 2D.6 | кривые L(m)+штраф при разных λ, отметка минимума тапом | L2 λ=1 → 0,30; L1 → (6,6 − λ)/20, ноль с λ = 6,6 |
| 2D.7 | собирает квадраты в столбики SS_res и SS_tot | 21,1 / 242 → R² = 0,913; веха `regression_2d` |
| L.0–L.2 | говорит с пасечником, выбирает метод (L1), «Обучить» | мёд = 14,36 − 0,0072·расстояние + 0,577·пчёлы |
| L.3–L.4 | у 5 ульев: пчёлы, поляна (расстояние), «Внести»; потом «Собрать мёд» | прогнозы 24,79 … 37,20 кг |
| L.5 | R² своих ульев, «А если бы OLS?» | R² = 0,989; OLS: −0,78; веха `regression_lore` |

## Что добавлено в SkRob (чужие объекты не изменены)
```
Workspace/RegressionLevel/                 Folder: FlowerbedAnchor, LoreAnchor — площадки модуля (в игре скрыты)
ReplicatedStorage/Regression/              весь код модуля (ModuleScript)
  MathCore · Data/{Datasets, ExpectedValues}
  Core/    Config, Format, Store, LineModel, Records, BedGeometry       — логика без Roblox API
  UI/      Theme, Strings, Gui, Hud, PlotView2D, FormulaView, Notebook, Shell2D, Slider, Drag, Viewport3D, R2View
  World/   Flowerbed, Scoreboard, NextBoard, LoreWorld
  Input/   LineControls, PlayerControls
  Scenes/  Flow3D (3D.1–3D.6), SceneMachine, Screens2D/S2D_*, Lore/LoreScenes
  Tests/   MathCoreSpec, LogicSpec
ReplicatedStorage/Remotes/RegressionProgress    RemoteEvent: вехи модуля
ServerScriptService/Server/RegressionProgress   Script: веха → LearningService.Complete (как у других уроков)
ServerScriptService/RegressionTests             Script: автотесты при запуске в Studio
StarterPlayer/StarterPlayerScripts/RegressionClient   LocalScript: точка входа
```
Всё обучение идёт на клиенте (клумба, табло, экраны, пасека — локальные объекты игрока). Сервер получает только вехи
`regression_3d`, `regression_2d`, `regression_lore`. HUD модуля стоит слева сверху (справа — HUD тайкуна SkRob) и
виден только у клумбы/пасеки. В SkRob включён StreamingEnabled — клиент ждёт якоря через `WaitForChild`.

## Как вносить изменения
Исходники — `src/` в раскладке Rojo (`X.luau` → ModuleScript, `X.client.luau` → LocalScript, `X.server.luau` → Script,
`X.rbxmx` → модель). После правок:
```
./tools/build_place.sh        # влить src/ в SkRob.rbxl и RegressionBeeHive.rbxlx (нужен Rust: собирает tools/rbxtool)
```
`tools/rbxtool` — утилита на rbx-dom (те же библиотеки, что у Rojo): `tree`, `export`, `sync`, `dumpall` и др. —
список в начале `tools/rbxtool/src/main.rs`. Папка `ReplicatedStorage/Regression` пересобирается начисто, остальное
добавляется/обновляется точечно. Площадки уровня задаются в `tools/level.py`.

## Проверка вне Studio
```
luau tests/run.luau                                  # 222/222 — MathCore (160) + логика 3D (62)
python3 tests/bundle.py && luau tests/scenario.luau  # 142/142 — сквозной путь игрока 3D → 2D → лор на моке Roblox
```
Мок (`tests/mock/Roblox.luau`) проверяет имена и типы свойств и Enum по reflection-базе rbx-dom, время в нём виртуальное.
Он не рисует интерфейс, поэтому вёрстку (раскладка формул, глифы Σ λ ⇒ ˆ в BuilderSans, телефон) смотри в Studio.
`luau` — https://github.com/luau-lang/luau (собирается из исходников: `cmake` + `make Luau.Repl.CLI`).

Математика: новые функции сначала в `tools/regression_math/scripts/reference_math.py`, затем
`export_expected.py` → `json_to_luau.py <папка>` → `src/ReplicatedStorage/Regression/Data/ExpectedValues.luau`, потом MathCore и тест.

## Решения по ТЗ
| Место | Решение |
|---|---|
| 3D, вращение прямой | вокруг середины над x̄ = 2,5 м; записи привязаны к высоте, при смене высоты старые бледнеют (минимум по m от h не зависит) |
| 3D, клавиши | ProximityPrompt — F (E занята наклоном); в режиме пульта движение и shift-lock выключены |
| 2D.1 | график переводится из MSE в L = n·MSE действием игрока (кнопка), чтобы формулы и график были в одних единицах; точки игрока × n |
| 2D.2 → 2D.3 | один экран: после первого сдвига прямой сразу 2D.3; записи различаются по c ≥ 1 кг; прямая прилипает к сетке 0,1 и к c* (±0,3) |
| 2D.4 | плоскость модели — сетка линий (параллелограмм одной деталью не нарисовать); остальные 10 точек — кольца в 2D-оверлее |
| 2D.5 | коэффициенты должны **оставаться внутри** круга/ромба; решение — касание самого низкого эллипса; пути λ считаются один раз (сетка 401) |
| 2D.6 | «впервые ноль» засчитывается при отпускании ползунка на λ ∈ [6,6; 6,9] |
| Лор, R² | у игрока 5 ульев (R² по одному не определён) |
| Лор, расстояние | сюжетная величина на табличке поляны; путь в мире пропорционален (0,012 studs/м + 4 studs) |
| Лор, «до пасеки» | расстояние от улья до ближайшей поляны (признак модели) |
| Лор, NPC | пасечник выдаёт задание (L.0) и возвращает к закрытому экрану; после первого улья — пчела-помощник считает пчёл, до полян игрок ходит сам |
| Встраивание | площадки на свободной земле у спауна SkRob; HUD модуля только рядом с ними; вехи — в LearningService |

## Открытые вопросы
- Сохранение прогресса между сессиями (DataStore) — вне рамок; состояние готово к сериализации (`Store.serialize`).
- Нужен ли короткий шаг про стандартизацию (2D.5 и лор её используют, сейчас — только подпись «в единицах sd»).
- Награды за ставки — сейчас косметический «мёд» модуля, с ресурсом Honey тайкуна SkRob не связан.
