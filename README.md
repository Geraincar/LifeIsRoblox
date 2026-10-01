# «Улей» · модуль «Регрессия» · 3D experience

Клумба с 5 цветками → нити-ошибки → квадраты ошибок → управление прямой (Q/E, Shift/Ctrl) →
5 записей (m, MSE) на табло → парабола и минимум m* = 0,33 → второе табло → экран 2D.

## Быстрый старт
1. Открой `RegressionBeeHive.rbxlx` в Roblox Studio (File → Open from File).
2. Play (F5). В Output: `Regression ИТОГО: 172/172`.
3. Подойди к клумбе (30 studs вперёд от спауна).

## Структура (в Studio — те же объекты)
```
ReplicatedStorage/Regression/            Folder
  MathCore                               ModuleScript — математическое ядро (110 эталонных проверок)
  Data/Datasets, Data/ExpectedValues     ModuleScript — данные клумбы и эталон
  Core/Config, Format, Store, LineModel, Records, BedGeometry   ModuleScript — логика без Roblox API
  UI/Theme, Strings, Gui, PlotView2D, Hud, Screen2D            ModuleScript — интерфейс
  World/Flowerbed, Scoreboard, NextBoard                       ModuleScript — объекты в мире
  Input/LineControls                     ModuleScript — Q/E, Shift/Ctrl, R, X, геймпад, кнопки телефона
  Scenes/Flow3D                          ModuleScript — шаги 3D.1–3D.6
  Tests/MathCoreSpec, Tests/LogicSpec    ModuleScript — автотесты
ServerScriptService/RegressionTests      Script — прогон тестов (только в Studio)
StarterPlayer/StarterPlayerScripts/RegressionClient   LocalScript — точка входа
Workspace/FlowerbedAnchor                Part — где строить клумбу (необязательно)
```
Файл `X.luau` → ModuleScript `X`; `X.client.luau` → LocalScript; `X.server.luau` → Script.

## Проверка вне Studio
```
luau tests/run.luau                              # 172/172 — ядро + логика
python3 tests/bundle.py && luau tests/scenario.luau   # 64/64 — сквозной сценарий игрока на моке Roblox
python3 tools/build_place.py src RegressionBeeHive.rbxlx   # пересобрать place из src/
```
`luau` — https://github.com/luau-lang/luau/releases
