"""Assemble the Hugging Face upload folder that transformers.js expects.

Copies config and tokenizer files from the ONNX export, falling back to the fused MLX
model, and makes sure tokenizer_config.json carries the chat template: transformers.js
3.x reads it only from there, while newer Python libraries may save it separately.

Usage: python prepare_upload.py <onnx_export_dir> <fused_model_dir> <upload_dir>
"""
import json
import shutil
import sys
from pathlib import Path

onnx_dir, fused_dir, out = (Path(p) for p in sys.argv[1:4])
REQUIRED = ["config.json", "tokenizer.json", "tokenizer_config.json"]
OPTIONAL = ["generation_config.json", "special_tokens_map.json"]

for name in REQUIRED + OPTIONAL:
    src = next((d / name for d in (onnx_dir, fused_dir) if (d / name).exists()), None)
    if src:
        shutil.copy(src, out / name)
        print(f"  {name}  (from {src.parent.name})")
    elif name in REQUIRED:
        sys.exit(f"Missing {name} in both {onnx_dir} and {fused_dir}; transformers.js needs it.")

cfg_path = out / "tokenizer_config.json"
cfg = json.loads(cfg_path.read_text())
if not cfg.get("chat_template"):
    template = None
    for d in (onnx_dir, fused_dir):
        if (d / "chat_template.jinja").exists():
            template = (d / "chat_template.jinja").read_text()
        elif (d / "chat_template.json").exists():
            template = json.loads((d / "chat_template.json").read_text()).get("chat_template")
        if template:
            break
    if not template:
        sys.exit("No chat template found; the browser model would not format conversations correctly.")
    cfg["chat_template"] = template
    cfg_path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False))
    print("  added chat_template to tokenizer_config.json")
print("upload folder ready:", out)
