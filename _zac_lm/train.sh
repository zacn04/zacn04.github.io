#!/usr/bin/env bash
# Build the Lean-checked fact sheet, generate training data, and LoRA fine-tune on the Mac.
# Run from anywhere:  bash _zac_lm/train.sh
# Heavy artifacts go to $BUILD (default ~/zac-lm-build), outside the website repo.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
BUILD="${BUILD:-$HOME/zac-lm-build}"
PY="${PY:-/Library/Frameworks/Python.framework/Versions/3.12/bin/python3}"
# MLX runs in its own venv: it needs no torch, so a broken torch/torchvision install in the
# system Python cannot break training.
MLX_VENV="${MLX_VENV:-$BUILD/.venv-mlx}"
BASE="${BASE:-HuggingFaceTB/SmolLM2-360M-Instruct}"
mkdir -p "$BUILD"

echo "== 1. Lean: prove the fact rules and export zac_kb.json"
command -v lake >/dev/null || { echo "Install Lean first: https://lean-lang.org/install (elan)"; exit 1; }
# `lake build` kernel-checks every theorem. The exporter then runs in Lean's interpreter
# rather than as a compiled binary, which recent macOS versions can refuse to load.
(cd "$HERE/lean" && lake build && lake env lean --run Main.lean "$REPO/zac_kb.json")

echo "== 2. Training data from the verified facts"
"$PY" "$HERE/build_dataset.py" --kb "$REPO/zac_kb.json" --out "$BUILD/data"

if command -v node >/dev/null; then
  echo "== 3. Check every training answer passes the website's answer checker"
  node "$HERE/test_checker.mjs" "$REPO/zac_kb.json" "$BUILD/data"
else
  echo "== 3. Skipped (install Node to run test_checker.mjs)"
fi

echo "== 4. LoRA fine-tune ($BASE)"
if [ ! -x "$MLX_VENV/bin/mlx_lm.lora" ]; then
  echo "Setting up an isolated MLX environment in $MLX_VENV"
  "$PY" -m venv "$MLX_VENV"
  "$MLX_VENV/bin/pip" install -q --upgrade pip
  "$MLX_VENV/bin/pip" install -q mlx-lm
fi
MLX_BIN="$MLX_VENV/bin"
"$MLX_BIN/mlx_lm.lora" \
  --model "$BASE" \
  --train \
  --data "$BUILD/data" \
  --iters 500 \
  --batch-size 4 \
  --num-layers 16 \
  --learning-rate 2e-4 \
  --adapter-path "$BUILD/adapters"

echo "== 5. Fuse the adapter into a standalone model"
"$MLX_BIN/mlx_lm.fuse" \
  --model "$BASE" \
  --adapter-path "$BUILD/adapters" \
  --save-path "$BUILD/fused_model"

echo "== 6. Sanity check: 8 questions with the real system prompt"
"$MLX_BIN/python" "$HERE/sanity.py" --model "$BUILD/fused_model" --kb "$REPO/zac_kb.json"
echo "Done. Next: bash $HERE/export_onnx.sh"
