"""Ask the fused model 8 questions, with the same prompt format the website builds, and run
the website's answer checker on each reply (via Node, if installed)."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

from mlx_lm import generate, load

# Facts (and proofs) listed in the order the website's retrieval puts them.
QUESTIONS = [
    ("What is Zac researching at Pramaana?", ["pramaana", "research-interests"], []),
    ("Summarize Zac's ICML 2026 papers", ["paper-lean", "qedbench", "paper-lean-results"], []),
    ("How does the SPRINT game engine work?", ["sprintgame", "sprintgame-engine"], []),
    ("What was Zac's GPA?", ["mit", "tonbridge"], []),
    ("Where has Zac worked?", ["pramaana", "meta-mle", "meta-intern"], []),
    ("What are Zac's hobbies?", ["music", "interests", "athletics"], []),
    ("How do you know Zac left Meta before Pramaana?", ["pramaana", "meta-mle"], ["meta_before_pramaana", "graduated_before_meta"]),
    ("What is Zac's home address?", ["contact"], []),
]

ap = argparse.ArgumentParser()
ap.add_argument("--model", required=True)
ap.add_argument("--kb", required=True)
a = ap.parse_args()
kb = json.loads(Path(a.kb).read_text())
facts = {f["id"]: f for f in kb["facts"]}
proofs = {p["name"]: p for p in kb["proofs"]}
model, tok = load(a.model)
replies = []
for q, ids, names in QUESTIONS:
    lines = [f"- [{i}] {facts[i]['text']}" for i in ids] + [f"- [proof:{n}] {proofs[n]['doc']}" for n in names]
    system = kb["system_prompt"].replace("{facts}", "\n".join(lines))
    prompt = tok.apply_chat_template([{"role": "system", "content": system}, {"role": "user", "content": q}],
                                     tokenize=False, add_generation_prompt=True)
    out = generate(model, tok, prompt=prompt, max_tokens=320)
    replies.append({"q": q, "a": out})
    print(f"\nQ: {q}\nA: {out}")

if shutil.which("node"):
    js = """
import { readFileSync } from "node:fs";
const core = await import("data:text/javascript," + encodeURIComponent(readFileSync(process.argv[1], "utf8")));
const kb = JSON.parse(readFileSync(process.argv[2], "utf8"));
for (const r of JSON.parse(readFileSync(0, "utf8"))) {
  const v = core.verifyAnswer(r.a, kb);
  console.log(v.ok ? "PASS" : "WITHHELD " + JSON.stringify(v.problems), "|", r.q);
}"""
    core = Path(__file__).resolve().parent.parent / "ask-ai-core.js"
    subprocess.run(["node", "--input-type=module", "-e", js, str(core), a.kb], input=json.dumps(replies), text=True, check=True)
