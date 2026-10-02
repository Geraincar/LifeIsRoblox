#!/usr/bin/env bash
# Собирает place-файлы без Studio:
#   SkRob.rbxl               — общий place команды: src/ (модуль «Регрессия»; ReplicatedStorage/Regression — начисто)
#                              + team-patches/ (правленые скрипты коллег: LevelFlow, лаборатория деревьев).
#                              Остальные объекты карты не трогаются.
#   RegressionBeeHive.rbxlx  — лёгкая песочница модуля «Регрессия» (baseplate), только src/.
# Новую карту команды подложи как SkRob.rbxl и запусти скрипт снова.
# Требуется Rust (cargo) для tools/rbxtool — он собирается при первом запуске.
set -euo pipefail
cd "$(dirname "$0")/.."
RBXTOOL=${RBXTOOL:-tools/rbxtool/target/release/rbxtool}
if [ ! -x "$RBXTOOL" ]; then
	cargo build --release --manifest-path tools/rbxtool/Cargo.toml
fi
python3 tools/level.py
"$RBXTOOL" sync SkRob.rbxl src SkRob.rbxl --own ReplicatedStorage/Regression
"$RBXTOOL" sync SkRob.rbxl team-patches SkRob.rbxl
"$RBXTOOL" sync RegressionBeeHive.rbxlx src RegressionBeeHive.rbxlx --own ReplicatedStorage/Regression --own Workspace/FlowerbedAnchor
echo "SkRob.rbxl и RegressionBeeHive.rbxlx собраны"
