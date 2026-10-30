#!/usr/bin/env bash
# Export the fused model to 4-bit ONNX for @huggingface/transformers in the browser,
# laid out the way transformers.js expects (config + tokenizer at the root, weights in onnx/).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="${BUILD:-$HOME/zac-lm-build}"
PY="${PY:-/Library/Frameworks/Python.framework/Versions/3.12/bin/python3}"
HF_REPO="${HF_REPO:-zacn04/zac-smollm2-onnx}"

if [ ! -d "$BUILD/.venv" ]; then
  "$PY" -m venv "$BUILD/.venv"
  "$BUILD/.venv/bin/pip" install -q "optimum[onnxruntime]" transformers onnx onnxruntime huggingface_hub
fi
VPY="$BUILD/.venv/bin/python"

rm -rf "$BUILD/onnx_fp32" "$BUILD/hf_upload"
"$BUILD/.venv/bin/optimum-cli" export onnx \
  --model "$BUILD/fused_model" \
  --task text-generation-with-past \
  "$BUILD/onnx_fp32"

mkdir -p "$BUILD/hf_upload/onnx"
"$VPY" "$HERE/quantize_q4.py" "$BUILD/onnx_fp32/model.onnx" "$BUILD/hf_upload/onnx/model_q4.onnx"
for f in config.json generation_config.json tokenizer.json tokenizer_config.json special_tokens_map.json; do
  [ -f "$BUILD/onnx_fp32/$f" ] && cp "$BUILD/onnx_fp32/$f" "$BUILD/hf_upload/"
done
du -sh "$BUILD/hf_upload"

cat <<MSG

Exported to $BUILD/hf_upload. To publish it (the repo will be public):
  $BUILD/.venv/bin/huggingface-cli login
  $BUILD/.venv/bin/huggingface-cli upload $HF_REPO $BUILD/hf_upload . --repo-type model
Until you upload, the website falls back to the base SmolLM2 model.
MSG
