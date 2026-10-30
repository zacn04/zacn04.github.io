# Ask Zac AI: Lean-checked facts, LoRA fine-tune, in-browser model

This folder is not published by GitHub Pages (Jekyll skips folders that start with `_`).

## How the pieces fit

1. **`lean/`** holds the fact sheet (`ZacFacts/Data.lean`) and the rules it must satisfy
   (`ZacFacts/Checks.lean`). The kernel proves the date and number rules with `decide`, so
   `lake build` fails if an edit breaks one. `lake exe zackb` then checks the text rules
   (no em dashes, no blocked terms, every proved number appears in its fact as written) and
   only then writes `../zac_kb.json` with `"verifier": "lean"`.
2. **`build_dataset.py`** turns `zac_kb.json` into `train.jsonl` and `valid.jsonl`. Answers
   are copied from verified facts or are fixed refusals. It refuses a fact sheet that did
   not come from Lean.
3. **`train.sh`** runs steps 1 and 2, checks every training answer with the website's own
   checker (`test_checker.mjs`), LoRA fine-tunes SmolLM2-360M with MLX, fuses it, and asks
   it 5 questions (`sanity.py`).
4. **`export_onnx.sh`** exports the fused model to 4-bit ONNX for transformers.js and
   prints the Hugging Face upload command.
5. On the site, **`ask-ai.js`** retrieves relevant facts, runs the model in the browser, and
   shows an answer only if every number, month and year, link, and watched organisation in
   it appears in `zac_kb.json` (logic in `ask-ai-core.js`). Otherwise it shows the facts.

## Run it on the Mac

```bash
# once: install Lean (https://lean-lang.org/install) and, optionally, Node
cd ~/zacn04.github.io && git fetch && git checkout claude/optimistic-cray-gwlslx && git pull
# optional: private terms that must never appear (one per line, never committed)
echo "a private term" >> _zac_lm/private_blocklist.txt
bash _zac_lm/train.sh          # Lean, data, checks, LoRA, fuse, sanity check
bash _zac_lm/export_onnx.sh    # ONNX q4, then follow the upload instructions it prints
git add zac_kb.json && git commit -m "Add Lean-verified fact sheet" && git push
```

To change a fact, edit `lean/ZacFacts/Data.lean` and run `train.sh` again. If you change
a number that a theorem talks about, update the structure (for example `negTransfer`) and
the text together, or the build stops.

## What the check does not catch

A true value used in the wrong context, for example a real date attached to the wrong role,
passes. So does a wrong claim with no number, date, link, or watched organisation in it.
