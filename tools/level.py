"""Генерирует объекты уровня «Регрессия» для общего мира SkRob (Rojo-совместимые .rbxmx в src/):
  src/Workspace/RegressionLevel.rbxmx              — Folder с якорями FlowerbedAnchor и LoreAnchor
  src/ReplicatedStorage/Remotes/RegressionProgress.rbxmx — RemoteEvent вех прогресса
  src/ReplicatedStorage/Regression/Core/LevelLayout.luau — те же координаты для клиента и тестов
  (в RegressionLevel.rbxmx добавлена деталь RegressionZone — куб уровня)
Площадки выбраны по свободному месту на карте SkRob рядом со спауном (земля — «Texture Part», верх на y = −30,58).
Локальная +Z якоря смотрит на спаун: игрок подходит к клумбе со стороны пульта, к пасеке — со стороны пасечника.
Использование: python3 tools/level.py
"""
import math, os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUND_Y = -30.5758
SPAWN = (3.1, 1.7)
# Куб уровня «Регрессия»: накрывает клумбу, оба табло и пасеку с запасом 12 studs.
# Кнопки квестов модуля (подсказки F, HUD, пульт) работают только внутри него.
# Границы по x: слева — до улья другого квеста (x ≤ −28,7), справа — далеко от TreeLevelZone (x ≥ 164).
# Если меняешь клумбу/пасеку — проверь размер: тест tests/scenario.luau сверяет, что весь мир модуля внутри куба.
ZONE = {"center": (34.5, 6.0, 20.0), "size": (123.0, 78.0, 148.0)}
ANCHORS = [
    # имя, центр (x, z), размер (x, y, z), цвет
    ("FlowerbedAnchor", (62.0, -28.0), (20, 1, 12), (255, 170, 0)),
    ("LoreAnchor", (5.0, 62.0), (40, 1, 44), (106, 191, 89)),
]


def cframe(x, y, z, look):
    # CFrame.lookAt(pos, pos + look): −Z = look, Y — вверх
    lx, lz = look
    n = math.hypot(lx, lz)
    lx, lz = lx / n, lz / n
    zx, zz = -lx, -lz          # ось Z
    rx, rz = zz, -zx           # ось X = Y × Z
    r = [[rx, 0, zx], [0, 1, 0], [rz, 0, zz]]
    names = ["R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    vals = [r[i][j] for i in range(3) for j in range(3)]
    body = "".join(f"<{k}>{v:.6f}</{k}>" for k, v in zip(names, vals))
    return f'<CoordinateFrame name="CFrame"><X>{x}</X><Y>{y}</Y><Z>{z}</Z>{body}</CoordinateFrame>'


def color(r, g, b):
    return (0xFF << 24) | (r << 16) | (g << 8) | b


items = []
for i, (name, (x, z), size, col) in enumerate(ANCHORS):
    look = (x - SPAWN[0], z - SPAWN[1])  # −Z — от спауна, +Z — к спауну
    items.append(f'''<Item class="Part" referent="RBX{i + 2}"><Properties>
<string name="Name">{name}</string><bool name="Anchored">true</bool><bool name="CanCollide">false</bool>
<bool name="CanQuery">false</bool><bool name="CanTouch">false</bool><bool name="CastShadow">false</bool><bool name="Locked">false</bool>
<Vector3 name="size"><X>{size[0]}</X><Y>{size[1]}</Y><Z>{size[2]}</Z></Vector3>
{cframe(x, GROUND_Y + size[1] / 2, z, look)}
<Color3uint8 name="Color3uint8">{color(*col)}</Color3uint8><float name="Transparency">0.7</float>
</Properties></Item>''')

zx, zy, zz = ZONE["center"]
zsx, zsy, zsz = ZONE["size"]
items.append(f'''<Item class="Part" referent="RBX9"><Properties>
<string name="Name">RegressionZone</string><bool name="Anchored">true</bool><bool name="CanCollide">false</bool>
<bool name="CanQuery">false</bool><bool name="CanTouch">false</bool><bool name="CastShadow">false</bool><bool name="Locked">true</bool>
<Vector3 name="size"><X>{zsx}</X><Y>{zsy}</Y><Z>{zsz}</Z></Vector3>
{cframe(zx, zy, zz, (0, -1))}
<Color3uint8 name="Color3uint8">{color(86, 180, 233)}</Color3uint8><float name="Transparency">0.92</float>
</Properties></Item>''')

level = f'''<roblox version="4"><Item class="Folder" referent="RBX1"><Properties><string name="Name">RegressionLevel</string></Properties>
{"".join(items)}
</Item></roblox>
'''
open(os.path.join(root, "src", "Workspace", "RegressionLevel.rbxmx"), "w", encoding="utf-8").write(level)
remote = '''<roblox version="4"><Item class="RemoteEvent" referent="RBX1"><Properties><string name="Name">RegressionProgress</string></Properties></Item></roblox>
'''
open(os.path.join(root, "src", "ReplicatedStorage", "Remotes", "RegressionProgress.rbxmx"), "w", encoding="utf-8").write(remote)
# Те же числа — в Luau: клиент берёт куб из детали RegressionZone, а если её нет в месте — отсюда; тесты строят мир по ним
layout = f"""-- Сгенерировано tools/level.py. Не редактировать.
-- Площадки модуля «Регрессия» в мире SkRob и куб уровня (RegressionZone).
return {{
	groundY = {GROUND_Y},
	spawn = Vector3.new({SPAWN[0]}, {GROUND_Y}, {SPAWN[1]}),
	anchors = {{
{"".join(f'		{{ name = "{n}", x = {x}, z = {z}, size = Vector3.new({sz[0]}, {sz[1]}, {sz[2]}) }},' + chr(10) for n, (x, z), sz, _ in ANCHORS)}	}},
	zone = {{ center = Vector3.new({zx}, {zy}, {zz}), size = Vector3.new({zsx}, {zsy}, {zsz}) }},
}}
"""
open(os.path.join(root, "src", "ReplicatedStorage", "Regression", "Core", "LevelLayout.luau"), "w", encoding="utf-8").write(layout)
print("written RegressionLevel.rbxmx, RegressionProgress.rbxmx, LevelLayout.luau")
