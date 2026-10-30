// Tests the Ask AI answer checker against the fact sheet and the training data.
// Usage: node test_checker.mjs <zac_kb.json> [<dir with train.jsonl and valid.jsonl>]
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const src = readFileSync(fileURLToPath(new URL("../ask-ai-core.js", import.meta.url)), "utf8");
const core = await import("data:text/javascript," + encodeURIComponent(src));
const kb = JSON.parse(readFileSync(process.argv[2], "utf8"));
const allowed = core.allowedClaims(kb);
const index = core.buildIndex(kb);
let failures = 0;
const check = (name, cond) => { if (!cond) { failures++; console.log("FAIL", name); } };

// 1. Every fact passes its own check.
for (const f of kb.facts) check(`fact ${f.id} verifies`, core.verifyAnswer(f.text, kb, allowed).ok);

// 2. Every answer the model is trained on passes.
if (process.argv[3]) {
  let n = 0;
  for (const name of ["train", "valid"]) {
    for (const line of readFileSync(`${process.argv[3]}/${name}.jsonl`, "utf8").split("\n").filter(Boolean)) {
      const msgs = JSON.parse(line).messages;
      for (let i = 0; i < msgs.length; i++) {
        if (msgs[i].role !== "assistant") continue;
        n++;
        const r = core.verifyAnswer(msgs[i].content, kb, allowed, msgs[i - 1].content);
        check(`${name} answer verifies: ${msgs[i].content.slice(0, 50)} ${JSON.stringify(r)}`, r.ok);
      }
    }
  }
  console.log(`checked ${n} training answers`);
}

// 3. Invented claims are caught.
const bad = [
  ["Zac graduated from MIT in June 2025.", "june 2025"],
  ["Zac joined Pramaana in 2019.", "2019"],
  ["The base model scored 71.2% on MATH-500.", "71.2"],
  ["Zac's GPA was 4.9/5.0.", "4.9"],
  ["You can email Zac at zac@pramaana.ai.", "zac@pramaana.ai"],
  ["See https://zacburton.com/cv.pdf for more.", "zacburton.com/cv.pdf"],
  ["Zac previously interned at Google DeepMind.", "google"],
  ["Zac is building a startup called Bellman.", "bellman"],
];
for (const [text, culprit] of bad) {
  const r = core.verifyAnswer(text, kb, allowed);
  check(`rejects "${text}"`, !r.ok && [...r.unverified, ...r.blocked].includes(culprit));
}
// Known limitation: a true date attached to the wrong event passes.
check("known limitation: real date in wrong context passes", core.verifyAnswer("Zac graduated from MIT in May 2025.", kb, allowed).ok);
check("true restatement passes", core.verifyAnswer("Zac got a GPA of 4.6/5.0 at MIT and graduated in February 2026.", kb, allowed).ok);
check("number from the question is allowed", core.verifyAnswer("I do not have verified information about 2019.", kb, allowed, "What did Zac do in 2019?").ok);
check("em dash is cleaned", core.cleanAnswer("Zac \u2014 at MIT") === "Zac, at MIT");

// 4. Retrieval puts the right fact first for the starter questions.
const starters = [
  ["What is Zac researching at Pramaana?", "pramaana"],
  ["Summarize Zac's ICML 2026 papers", ["paper-lean", "qedbench", "paper-lean-results"]],
  ["How does the SPRINT game engine work?", "sprintgame-engine"],
  ["What classes did Zac take at MIT?", ["courses-other", "courses-math"]],
  ["What was Zac's GPA?", "mit"],
  ["Has Zac taught?", "teaching"],
];
for (const [q, want] of starters) {
  const top = core.retrieve(index, q, 3).map((f) => f.id);
  const wants = [].concat(want);
  check(`retrieve "${q}" -> ${top}`, wants.includes(top[0]));
}
console.log(failures ? `${failures} failure(s)` : "all checks passed");
process.exit(failures ? 1 : 0);
