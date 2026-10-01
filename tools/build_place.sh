#!/usr/bin/env bash
# Собирает place-файлы из src/ (Rojo-раскладка) без Studio:
#   SkRob.rbxl               — общий place команды: добавляет/обновляет только объекты модуля «Регрессия»,
#                              чужие объекты не трогает; ReplicatedStorage/Regression пересобирается начисто.
#   RegressionBeeHive.rbxlx  — лёгкая песочница модуля (baseplate), удобна для быстрой проверки в Studio.
# Требуется Rust (cargo) для tools/rbxtool — он собирается при первом запуске.
set -euo pipefail
cd "$(dirname "$0")/.."
RBXTOOL=${RBXTOOL:-tools/rbxtool/target/release/rbxtool}
if [ ! -x "$RBXTOOL" ]; then
	cargo build --release --manifest-path tools/rbxtool/Cargo.toml
fi
python3 tools/level.py
"$RBXTOOL" sync SkRob.rbxl src SkRob.rbxl --own ReplicatedStorage/Regression
"$RBXTOOL" sync RegressionBeeHive.rbxlx src RegressionBeeHive.rbxlx --own ReplicatedStorage/Regression --own Workspace/FlowerbedAnchor
echo "SkRob.rbxl и RegressionBeeHive.rbxlx собраны из src/"
