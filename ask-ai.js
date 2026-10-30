// Ask AI tab: instant answers from the Lean-checked fact sheet, plus a small language
// model that runs in the browser. Every model answer is checked before it is shown.
import { buildIndex, retrieve, buildMessages, allowedClaims, verifyAnswer, cleanAnswer } from "./ask-ai-core.js";

const TRANSFORMERS_URL = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3";
// Tried in order. The first is the fine-tuned model; the rest are base-model fallbacks.
const MODELS = [
  { id: "zacn04/zac-smollm2-onnx", dtype: "q4", label: "fine-tuned SmolLM2-360M" },
  { id: "HuggingFaceTB/SmolLM2-360M-Instruct", dtype: "q4", label: "base SmolLM2-360M" },
  { id: "HuggingFaceTB/SmolLM2-360M-Instruct", dtype: "q4f16", label: "base SmolLM2-360M" },
  { id: "onnx-community/Qwen2.5-0.5B-Instruct", dtype: "q4", label: "base Qwen2.5-0.5B" },
];

const $ = (id) => document.getElementById(id);
const log = $("ai-log");
const form = $("ai-form");
const input = $("ai-input");
const status = $("ai-status");
const bar = $("ai-progress");
const loadBtn = $("ai-load");

let kb, index, allowed;
let generator = null;
let loading = null;
let lastQuestion = "";
const history = [];

function bubble(role, text, cls = "") {
  const div = document.createElement("div");
  div.className = `ai-msg ai-${role} ${cls}`.trim();
  if (text) div.textContent = text;
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
  return div;
}

function note(el, text, cls) {
  const p = document.createElement("p");
  p.className = `ai-note ${cls}`;
  p.textContent = text;
  el.appendChild(p);
}

function factsBubble(facts, lead) {
  const div = bubble("bot", "");
  const p = document.createElement("p");
  p.textContent = lead;
  div.appendChild(p);
  const ul = document.createElement("ul");
  for (const f of facts) {
    const li = document.createElement("li");
    li.textContent = f.text;
    ul.appendChild(li);
  }
  div.appendChild(ul);
  return div;
}

async function init() {
  try {
    kb = await (await fetch("zac_kb.json", { cache: "no-cache" })).json();
    if (kb.verifier !== "lean") throw new Error("not verified");
  } catch {
    status.textContent = "The verified fact sheet is not available yet, so Ask AI is turned off.";
    form.querySelectorAll("input, button").forEach((el) => (el.disabled = true));
    loadBtn.disabled = true;
    return;
  }
  index = buildIndex(kb);
  allowed = allowedClaims(kb);
  $("ai-theorems").textContent = kb.theorems.join(", ");
  status.textContent = "Instant answers come from the verified facts. Load the model for written answers.";
}

function loadModel() {
  if (loading) return loading;
  loadBtn.disabled = true;
  bar.hidden = false;
  loading = (async () => {
    status.textContent = "Loading the model library...";
    const { pipeline, TextStreamer } = await import(TRANSFORMERS_URL);
    const device = navigator.gpu ? "webgpu" : "wasm";
    for (const m of MODELS) {
      const files = new Map();
      try {
        status.textContent = `Downloading the ${m.label} model (about 250 to 350 MB, cached after the first time)...`;
        const pipe = await pipeline("text-generation", m.id, {
          dtype: m.dtype,
          device,
          progress_callback: (p) => {
            if (p.status !== "progress" || !p.total) return;
            files.set(p.file, [p.loaded, p.total]);
            let done = 0, total = 0;
            for (const [l, t] of files.values()) { done += l; total += t; }
            bar.value = Math.round((100 * done) / total);
          },
        });
        generator = { pipe, TextStreamer };
        bar.hidden = true;
        status.textContent = `Model ready: ${m.label}, running on ${device === "webgpu" ? "your GPU" : "your CPU"}.`;
        return generator;
      } catch (e) {
        console.warn("Ask AI: could not load", m.id, m.dtype, e);
      }
    }
    bar.hidden = true;
    status.textContent = "No model could load in this browser. Instant answers from the verified facts still work.";
    loading = null;
    loadBtn.disabled = false;
    throw new Error("no model");
  })();
  return loading;
}

async function modelAnswer(question, facts) {
  const { pipe, TextStreamer } = generator;
  const div = bubble("bot", "", "ai-draft");
  const label = document.createElement("p");
  label.className = "ai-note";
  label.textContent = "Unchecked draft";
  const body = document.createElement("p");
  div.append(label, body);
  let draft = "";
  const streamer = new TextStreamer(pipe.tokenizer, {
    skip_prompt: true,
    skip_special_tokens: true,
    callback_function: (t) => { draft += t; body.textContent = draft; log.scrollTop = log.scrollHeight; },
  });
  const out = await pipe(buildMessages(kb, facts, history.slice(-4), question), {
    max_new_tokens: 320, do_sample: false, streamer,
  });
  const answer = cleanAnswer(out[0].generated_text.at(-1).content || draft);
  const v = verifyAnswer(answer, kb, allowed, question);
  div.remove();
  if (v.ok) {
    const done = bubble("bot", answer);
    note(done, "Checked: every number, date, and link matches the Lean-verified facts.", "ai-ok");
    history.push({ role: "user", content: question }, { role: "assistant", content: answer });
  } else {
    const shown = factsBubble(facts.slice(0, 3), "I could not verify my answer, so here is what the verified facts say:");
    const why = [...v.unverified, ...v.blocked].join(", ");
    note(shown, `Withheld: the draft mentioned ${why}, which is not in the verified facts.`, "ai-bad");
  }
}

async function ask(question) {
  question = question.trim();
  if (!question || !kb) return;
  bubble("user", question);
  input.value = "";
  // Short follow-ups ("tell me more") reuse the previous question for retrieval.
  let facts = retrieve(index, question, 5);
  if (facts.length < 2 && lastQuestion) facts = retrieve(index, question + " " + lastQuestion, 5);
  lastQuestion = question;
  if (!facts.length) {
    bubble("bot", "I do not have verified information about that. You can email Zac at zacnburton@gmail.com.");
    return;
  }
  if (!generator) {
    factsBubble(facts.slice(0, 3), "From the verified facts:");
    try { await loadModel(); } catch { return; }
  }
  try {
    form.querySelector("button").disabled = true;
    await modelAnswer(question, facts);
  } catch (e) {
    console.warn("Ask AI: generation failed", e);
    bubble("bot", "Something went wrong while writing an answer. The verified facts above still apply.");
  } finally {
    form.querySelector("button").disabled = false;
  }
}

form.addEventListener("submit", (e) => { e.preventDefault(); ask(input.value); });
loadBtn.addEventListener("click", () => loadModel().catch(() => {}));
document.querySelectorAll(".ai-chip").forEach((b) => b.addEventListener("click", () => ask(b.textContent)));
init();
