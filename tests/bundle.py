"""Собирает исходники в таблицы «путь → текст» для тестов на моке (в standalone luau нет файловой системы):
  tests/_bundle.luau       — src/**/*.luau (модуль «Регрессия»)
  tests/_bundle_team.luau  — team-patches/**/*.luau + tests/fixtures/lab/**/*.luau (лаборатория деревьев)
Использование: python3 tests/bundle.py
"""
import os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bundle(dirs, out_name):
    out = ["-- Сгенерировано tests/bundle.py. Не редактировать.", "return {"]
    for base in dirs:
        for dirpath, _, files in sorted(os.walk(base)):
            for f in sorted(files):
                if not f.endswith(".luau"):
                    continue
                p = os.path.join(dirpath, f)
                rel = os.path.relpath(p, base).replace(os.sep, "/")
                text = open(p, encoding="utf-8").read()
                level = 1
                while ("]" + "=" * level + "]") in text:
                    level += 1
                eq = "=" * level
                out.append(f'\t["{rel}"] = [{eq}[\n{text}]{eq}],')
    out.append("}")
    open(os.path.join(root, "tests", out_name), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("bundled", sum(1 for l in out if l.startswith('\t["')), "files ->", out_name)


bundle([os.path.join(root, "src")], "_bundle.luau")
bundle([os.path.join(root, "team-patches"), os.path.join(root, "tests", "fixtures", "lab")], "_bundle_team.luau")
