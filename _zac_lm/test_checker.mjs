// Tests the Ask AI answer checker against the fact sheet and the training data.
// Usage: node test_checker.mjs <zac_kb.json> [<dir with train.jsonl and valid.jsonl>]
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const src = readFileSync(fileURLToPath(new URL("../ask-ai-core.js", import.meta.url)), "utf8");
const core = await import("data:text/javascript," + encodeURIComponent(src));
const kb = JSON.parse(readFileSync(process.argv[2], "utf8"));
const index = core.buildIndex(kb);
const fact = Object.fromEntries(kb.facts.map((f) => [f.id, f]));
let failures = 0;
const check = (name, cond) => { if (!cond) { failures++; console.log("FAIL", name); } };
const verify = (a) => core.verifyAnswer(a, kb);

// 1. Every fact, cited as a whole, passes; so does every template and proof answer.
for (const f of kb.facts) check(`fact ${f.id} verifies`, verify(`${f.text} [${f.id}]`).ok);
for (const [k, t] of Object.entries(kb.templates)) if (k !== "proof") check(`template ${k}`, verify(t).ok);
for (const p of kb.proofs) check(`proof ${p.name}`, verify(`${kb.templates.proof} [proof:${p.name}]`).ok);

// 2. Every answer the model is trained on passes.
if (process.argv[3]) {
  let n = 0;
  for (const name of ["train", "valid"]) {
    for (const line of readFileSync(`${process.argv[3]}/${name}.jsonl`, "utf8").split("\n").filter(Boolean)) {
      for (const m of JSON.parse(line).messages) {
        if (m.role !== "assistant") continue;
        n++;
        const r = verify(m.content);
        check(`${name} answer verifies: ${m.content.slice(0, 60)} ${JSON.stringify(r.problems)}`, r.ok);
      }
    }
  }
  console.log(`checked ${n} training answers`);
}

// 3. Anything not quoted exactly from the cited fact is rejected.
const internSentence = core.splitSentences(fact["meta-intern"].text)[0];
const bad = [
  ["paraphrase", "Zac joined Pramaana in September 2026. [pramaana]"],
  ["real sentence, wrong fact", `${internSentence} [mit]`],
  ["uncited invented sentence", "Zac graduated from MIT in May 2025."],
  ["uncited true sentence", fact.mit.text],
  ["unknown fact id", "Zac works at Pramaana Labs. [jobs]"],
  ["unknown proof", `${kb.templates.proof} [proof:zac_is_great]`],
  ["true citation plus extra claim", `${fact.mit.text} [mit] Zac also interned at Google.`],
  ["empty answer", ""],
];
for (const [name, a] of bad) check(`rejects ${name}`, !verify(a).ok);
check("em dash and curly quotes are normalised", verify(fact.music.text.replace(/'/g, "’") + " [music]").ok);
check("several citations pass", verify(`${fact.mit.text} [mit] ${fact.tonbridge.text} [tonbridge]`).ok);
const parts = verify(`${kb.templates.proof} [proof:${kb.proofs[0].name}]`).parts;
check("proof answer splits into text + proof", parts.length === 2 && parts[1].type === "proof");

// 4. Retrieval puts the right fact in the top 3 for the starter questions.
const starters = [
  ["What is Zac researching at Pramaana?", "pramaana"],
  ["Summarize Zac's ICML 2026 papers", ["paper-lean", "qedbench", "paper-lean-results"]],
  ["How does the SPRINT game engine work?", "sprintgame-engine"],
  ["What classes did Zac take at MIT?", ["courses-other", "courses-math"]],
  ["What was Zac's GPA?", "mit"],
  ["Has Zac taught?", "teaching"],
  ["Who is Zac?", "identity"],
];
for (const [q, want] of starters) {
  const top = core.retrieve(index, q, 5).slice(0, 3).map((f) => f.id);
  check(`retrieve "${q}" -> ${top}`, top.some((id) => [].concat(want).includes(id)));
}

// 5. Broad questions retrieve every fact their combined answer needs.
const broad = [
  ["Summarize Zac's ICML 2026 papers", ["paper-lean", "qedbench"]],
  ["Where has Zac worked?", ["pramaana", "meta-mle", "meta-intern"]],
  ["What is Zac's education?", ["mit", "tonbridge"]],
  ["What has Zac done with Lean?", ["pramaana", "paper-lean", "fcs"]],
  ["What projects has Zac built?", ["sprintgame", "pieface", "zos"]],
  ["What are Zac's hobbies?", ["music", "interests", "athletics"]],
  ["How is Zac involved in education?", ["teaching", "eloranta", "edu-despite-ai"]],
];
for (const [q, ids] of broad) {
  const top = core.retrieve(index, q, 5).map((f) => f.id);
  check(`broad "${q}" -> ${top}`, ids.every((id) => top.includes(id)));
}

// 6. Proof questions get the right proof; ordinary questions get none.
const proofQs = [
  ["How do you know Zac left Meta before Pramaana?", "meta_before_pramaana"],
  ["Prove Zac interned at Meta while at MIT.", "intern_during_mit"],
  ["How do you know every transfer condition was negative?", "neg_transfer_all_negative"],
  ["How do you know Zac's GPA is valid?", "gpa_in_range"],
  ["Prove the doubled budget solved 0 additional theorems.", "prover_plateau"],
];
for (const [q, name] of proofQs) {
  const got = core.retrieveProofs(kb, q).map((p) => p.name);
  check(`proofs for "${q}" -> ${got}`, got.includes(name));
}
check("no proofs for an ordinary question", core.retrieveProofs(kb, "Where did Zac go to college?").length === 0);

// 7. Vague questions are detected only when nothing is retrieved.
for (const q of ["What did Zac do?", "Hi", "What's Zac up to?", "Tell me something.", "Give me the highlights."]) {
  check(`vague: "${q}"`, core.isVague(q) && core.retrieve(index, q).length === 0);
}
for (const q of ["Who is Zac?", "What is the sprintgame?", "Where has Zac worked?"]) {
  check(`not vague: "${q}"`, core.retrieve(index, q).length > 0);
}

console.log(failures ? `${failures} failure(s)` : "all checks passed");
process.exit(failures ? 1 : 0);
