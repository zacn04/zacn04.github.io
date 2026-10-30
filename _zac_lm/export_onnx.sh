#!/usr/bin/env bash
# Export the fused model to 4-bit ONNX for @huggingface/transformers in the browser,
# laid out the way transformers.js expects (config + tokenizer at the root, weights in onnx/).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="${BUILD:-$HOME/zac-lm-build}"
PY="${PY:-/Library/Frameworks/Python.framework/Versions/3.12/bin/python3}"
HF_REPO="${HF_REPO:-zacnwo/zac-smollm2-onnx}"

if [ ! -f "$BUILD/fused_model/config.json" ]; then
  echo "No trained model at $BUILD/fused_model. Run bash _zac_lm/train.sh first, and check it finished."
  exit 1
fi

if [ ! -d "$BUILD/.venv" ]; then
  "$PY" -m venv "$BUILD/.venv"
  "$BUILD/.venv/bin/pip" install -q "optimum[onnxruntime]" transformers onnx onnxruntime huggingface_hub
fi
# onnx-ir is needed by newer onnxruntime's 4-bit quantizer; install it into existing venvs too.
"$BUILD/.venv/bin/pip" install -q onnx-ir
VPY="$BUILD/.venv/bin/python"

# Re-export only if the fused model is newer than the last export (the export is slow).
if [ ! -f "$BUILD/onnx_fp32/model.onnx" ] || [ "$BUILD/fused_model/config.json" -nt "$BUILD/onnx_fp32/model.onnx" ]; then
  rm -rf "$BUILD/onnx_fp32"
  "$BUILD/.venv/bin/optimum-cli" export onnx \
    --model "$BUILD/fused_model" \
    --task text-generation-with-past \
    "$BUILD/onnx_fp32"
else
  echo "Reusing the existing ONNX export in $BUILD/onnx_fp32"
fi
rm -rf "$BUILD/hf_upload"

mkdir -p "$BUILD/hf_upload/onnx"
"$VPY" "$HERE/quantize_q4.py" "$BUILD/onnx_fp32/model.onnx" "$BUILD/hf_upload/onnx/model_q4.onnx"
"$VPY" "$HERE/prepare_upload.py" "$BUILD/onnx_fp32" "$BUILD/fused_model" "$BUILD/hf_upload"
du -sh "$BUILD/hf_upload"

cat <<MSG

Exported to $BUILD/hf_upload. To publish it (the repo will be public):
  $BUILD/.venv/bin/huggingface-cli login
  $BUILD/.venv/bin/huggingface-cli upload $HF_REPO $BUILD/hf_upload . --repo-type model
Until you upload, the website falls back to the base SmolLM2 model.
MSG
