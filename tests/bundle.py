"""Собирает src/**/*.luau в tests/_bundle.luau (таблица путь → исходник) для сценарных тестов на моке.
В standalone luau нет файловой системы, поэтому исходники передаются так.
Использование: python3 tests/bundle.py
"""
import os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, "src")
out = ["-- Сгенерировано tests/bundle.py. Не редактировать.", "return {"]
for dirpath, _, files in sorted(os.walk(src)):
    for f in sorted(files):
        if not f.endswith(".luau"):
            continue
        p = os.path.join(dirpath, f)
        rel = os.path.relpath(p, src).replace(os.sep, "/")
        text = open(p, encoding="utf-8").read()
        level = 1
        while ("]" + "=" * level + "]") in text:
            level += 1
        eq = "=" * level
        out.append(f'\t["{rel}"] = [{eq}[\n{text}]{eq}],')
out.append("}")
open(os.path.join(root, "tests", "_bundle.luau"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("bundled", sum(1 for l in out if l.startswith('\t["')), "files")
