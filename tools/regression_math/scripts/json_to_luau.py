"""Конвертирует assets/datasets.json и assets/expected_values.json в Luau-модули,
которые можно положить в проект (Rojo или вручную в Studio).
Использование: python json_to_luau.py <выходная_папка>
Создаёт Datasets.luau и ExpectedValues.luau (каждый возвращает таблицу).
"""
import json, sys, os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lua(v, ind=0):
    pad = "\t" * ind
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if (k.isidentifier() and k.isascii() and k not in ("and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","continue","type","export")) else f'["{k}"]'
            items.append(f"{pad}\t{key} = {lua(x, ind + 1)},")
        return "{\n" + "\n".join(items) + f"\n{pad}}}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{" + ", ".join(lua(x) for x in v) + "}"
        return "{\n" + "\n".join(f"{pad}\t{lua(x, ind + 1)}," for x in v) + f"\n{pad}}}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(float(v)) if isinstance(v, float) else str(v)
    if v is None:
        return "nil"
    return json.dumps(v, ensure_ascii=False)


out = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(out, exist_ok=True)
for src, name in [("datasets.json", "Datasets"), ("expected_values.json", "ExpectedValues")]:
    data = json.load(open(os.path.join(root, "assets", src), encoding="utf-8"))
    with open(os.path.join(out, name + ".luau"), "w", encoding="utf-8") as f:
        f.write(f"-- Сгенерировано scripts/json_to_luau.py из assets/{src}. Не редактировать вручную.\n")
        f.write("return " + lua(data) + "\n")
    print("written", name + ".luau")
