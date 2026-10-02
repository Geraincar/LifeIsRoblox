"""Генерирует объекты уровня «Регрессия» для общего мира SkRob (Rojo-совместимые .rbxmx в src/):
  src/Workspace/RegressionLevel.rbxmx                    — Folder: FlowerbedAnchor, LoreAnchor, RegressionZone (куб уровня)
  src/ReplicatedStorage/Remotes/RegressionProgress.rbxmx — RemoteEvent вех прогресса
  src/ReplicatedStorage/Regression/Core/LevelLayout.luau — те же координаты для клиента (запасной вариант) и тестов
Координаты — как их расставила команда в общей карте (SkRob_vol2): площадки и куб повёрнуты вручную, поэтому
здесь хранится полный CFrame (позиция + матрица поворота по строкам), а не «направление на спаун».
Если в Studio передвинули площадку или куб — перенеси сюда их CFrame/Size (rbxtool props <place> Workspace/RegressionLevel/<имя>).
Использование: python3 tools/level.py
"""
import os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUND_Y = -30.575768
SPAWN = (41.965675, GROUND_Y, 1.0869448)

# имя, позиция, матрица поворота (строки R0x, R1x, R2x), размер, цвет, прозрачность в Studio, Locked
PARTS = [
    ("FlowerbedAnchor", (115.64024, -30.075768, -4.472183),
     ((0.7071072, 0.0, -0.70710653), (0.0, 1.0, 0.0), (0.70710653, 0.0, 0.7071072)),
     (20.0, 1.0, 12.0), (255, 170, 0), 0.7, False),
    ("LoreAnchor", (118.48942, -30.075768, 73.57159),
     ((-0.7071064, 0.0, -0.70710725), (0.0, 1.0, 0.0), (0.70710725, 0.0, -0.7071064)),
     (40.0, 1.0, 44.0), (106, 191, 89), 0.7, False),
    # Куб уровня: кнопки квестов модуля (подсказки F, HUD, пульт) работают только внутри него.
    ("RegressionZone", (114.435646, -12.134401, 35.826294),
     ((0.97657514, 0.0, 0.21517709), (0.0, 1.0, 0.0), (-0.21517709, 0.0, 0.97657514)),
     (89.78053, 61.882736, 165.9553), (86, 180, 233), 0.92, False),
]


def cframe_xml(pos, rot):
    names = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    vals = [rot[i][j] for i in range(3) for j in range(3)]
    body = "".join(f"<{k}>{v}</{k}>" for k, v in zip(names, vals))
    return f'<CoordinateFrame name="CFrame"><X>{pos[0]}</X><Y>{pos[1]}</Y><Z>{pos[2]}</Z>{body}</CoordinateFrame>'


def color(r, g, b):
    return (0xFF << 24) | (r << 16) | (g << 8) | b


items = []
for i, (name, pos, rot, size, col, tr, locked) in enumerate(PARTS):
    items.append(f'''<Item class="Part" referent="RBX{i + 2}"><Properties>
<string name="Name">{name}</string><bool name="Anchored">true</bool><bool name="CanCollide">false</bool>
<bool name="CanQuery">false</bool><bool name="CanTouch">false</bool><bool name="CastShadow">false</bool><bool name="Locked">{"true" if locked else "false"}</bool>
<Vector3 name="size"><X>{size[0]}</X><Y>{size[1]}</Y><Z>{size[2]}</Z></Vector3>
{cframe_xml(pos, rot)}
<Color3uint8 name="Color3uint8">{color(*col)}</Color3uint8><float name="Transparency">{tr}</float>
</Properties></Item>''')

level = f'''<roblox version="4"><Item class="Folder" referent="RBX1"><Properties><string name="Name">RegressionLevel</string></Properties>
{"".join(items)}
</Item></roblox>
'''
open(os.path.join(root, "src", "Workspace", "RegressionLevel.rbxmx"), "w", encoding="utf-8").write(level)
remote = '''<roblox version="4"><Item class="RemoteEvent" referent="RBX1"><Properties><string name="Name">RegressionProgress</string></Properties></Item></roblox>
'''
open(os.path.join(root, "src", "ReplicatedStorage", "Remotes", "RegressionProgress.rbxmx"), "w", encoding="utf-8").write(remote)


def lua_cf(pos, rot):
    vals = [pos[0], pos[1], pos[2]] + [rot[i][j] for i in range(3) for j in range(3)]
    return "CFrame.new(" + ", ".join(repr(v) for v in vals) + ")"


rows = []
for name, pos, rot, size, *_ in PARTS:
    rows.append(f'\t\t{name} = {{ cframe = {lua_cf(pos, rot)}, size = Vector3.new({size[0]}, {size[1]}, {size[2]}) }},\n')
layout = f"""-- Сгенерировано tools/level.py. Не редактировать.
-- Площадки модуля «Регрессия» и куб уровня (RegressionZone) — как в общей карте SkRob.
-- Клиент берёт детали из Workspace/RegressionLevel; эти числа — запасной вариант и основа тестов.
return {{
	groundY = {GROUND_Y},
	spawn = Vector3.new({SPAWN[0]}, {SPAWN[1]}, {SPAWN[2]}),
	parts = {{
{"".join(rows)}	}},
}}
"""
open(os.path.join(root, "src", "ReplicatedStorage", "Regression", "Core", "LevelLayout.luau"), "w", encoding="utf-8").write(layout)
print("written RegressionLevel.rbxmx, RegressionProgress.rbxmx, LevelLayout.luau")
