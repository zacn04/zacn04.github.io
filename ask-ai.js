// Ask AI tab: instant answers from the Lean-checked fact sheet, plus a small language
// model that runs in the browser. Every model answer is checked before it is shown.
import { buildIndex, retrieve, retrieveProofs, isVague, buildMessages, verifyAnswer } from "./ask-ai-core.js";

const TRANSFORMERS_URL = "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3";
// Tried in order. The first is the fine-tuned model; the rest are base-model fallbacks.
const MODELS = [
  { id: "zacnwo/zac-smollm2-onnx", dtype: "q4", label: "fine-tuned SmolLM2-360M" },
  { id: "HuggingFaceTB/SmolLM2-360M-Instruct", dtype: "q4", label: "base SmolLM2-360M" },
  { id: "HuggingFaceTB/SmolLM2-360M-Instruct", dtype: "q4f16", label: "base SmolLM2-360M" },
  { id: "onnx-community/Qwen2.5-0.5B-Instruct", dtype: "q4", label: "base Qwen2.5-0.5B" },
];

// Which tab each fact lives on, for the "Read more" links.
const TAB_FOR_TOPIC = { research: "research", projects: "projects" };
const TAB_FOR_FACT = { talks: "speaking" };
const TAB_LABEL = { about: "About", research: "Research", projects: "Projects", speaking: "Speaking" };

// Buttons offered when a question is too vague.
const TOPICS = [
  ["Work", "Where has Zac worked?"],
  ["Research", "What does Zac research?"],
  ["Projects", "What projects has Zac built?"],
  ["Interests", "What are Zac's hobbies?"],
];

const $ = (id) => document.getElementById(id);
const log = $("ai-log");
const form = $("ai-form");
const input = $("ai-input");
const status = $("ai-status");
const bar = $("ai-progress");
const loadBtn = $("ai-load");

let kb, index, factById;
let generator = null;
let loading = null;
let lastQuestion = "";
const history = [];

function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text) e.textContent = text;
  return e;
}

function bubble(role, cls = "") {
  const div = el("div", `ai-msg ai-${role} ${cls}`.trim());
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
  return div;
}

function note(parent, text, cls) {
  parent.appendChild(el("p", `ai-note ${cls}`, text));
}

function tabOf(fact) {
  return TAB_FOR_FACT[fact.id] || TAB_FOR_TOPIC[fact.topic] || "about";
}

function goToTab(name) {
  window.switchTab(name, document.querySelector(`[aria-controls="tab-${name}"]`));
  document.querySelector(".tab-bar").scrollIntoView({ behavior: "smooth" });
}

function tabLink(name) {
  const a = el("a", "", `${TAB_LABEL[name]} tab`);
  a.href = `#tab-${name}`;
  a.addEventListener("click", (e) => { e.preventDefault(); goToTab(name); });
  return a;
}

function readMore(parent, facts) {
  const tabs = [...new Set(facts.map(tabOf))];
  const p = el("p", "ai-note", "Read more: ");
  tabs.forEach((t, i) => { if (i) p.append(", "); p.append(tabLink(t)); });
  parent.appendChild(p);
}

function topicButtons(parent) {
  const row = el("div", "ai-chips");
  for (const [label, q] of TOPICS) {
    const b = el("button", "ai-chip", label);
    b.type = "button";
    b.addEventListener("click", () => ask(q));
    row.appendChild(b);
  }
  parent.appendChild(row);
}

function proofFigure(name) {
  const p = kb.proofs.find((x) => x.name === name);
  const fig = el("figure", "ai-proof");
  fig.appendChild(el("figcaption", "", `${p.doc} Checked by the Lean kernel:`));
  const pre = el("pre");
  pre.appendChild(el("code", "", p.source));
  fig.appendChild(pre);
  return fig;
}

function factsBubble(facts, lead) {
  const div = bubble("bot");
  div.appendChild(el("p", "", lead));
  const ul = el("ul");
  for (const f of facts) ul.appendChild(el("li", "", f.text));
  div.appendChild(ul);
  readMore(div, facts);
  return div;
}

function proofsBubble(proofs, lead) {
  const div = bubble("bot");
  div.appendChild(el("p", "", lead));
  for (const p of proofs) div.appendChild(proofFigure(p.name));
  return div;
}

function clarify() {
  const div = bubble("bot");
  div.appendChild(el("p", "", kb.templates.clarify));
  topicButtons(div);
}

// Render an answer that passed verifyAnswer: quoted sentences with their citations,
// proofs with their Lean source, and template replies.
function renderChecked(parts) {
  const div = bubble("bot");
  const cited = [];
  let p = el("p");
  for (const part of parts) {
    if (part.type === "proof") {
      if (p.childNodes.length) div.appendChild(p);
      div.appendChild(proofFigure(part.name));
      p = el("p");
      continue;
    }
    if (p.childNodes.length) p.append(" ");
    p.append(part.sentences.join(" "));
    if (part.type === "cite") {
      const f = factById.get(part.id);
      cited.push(f);
      const c = el("a", "ai-cite", part.id);
      c.href = `#tab-${tabOf(f)}`;
      c.title = f.text;
      c.addEventListener("click", (e) => { e.preventDefault(); goToTab(tabOf(f)); });
      p.append(" ", c);
    }
  }
  if (p.childNodes.length) div.appendChild(p);
  if (parts.some((x) => x.type === "text" && x.sentences.join(" ") === kb.templates.clarify)) topicButtons(div);
  if (cited.length || parts.some((x) => x.type === "proof")) {
    note(div, "Checked: every sentence is quoted word for word from a cited Lean-verified fact.", "ai-ok");
  }
  if (cited.length) readMore(div, cited);
}

async function init() {
  try {
    kb = await (await fetch("zac_kb.json", { cache: "no-cache" })).json();
    if (kb.verifier !== "lean") throw new Error("not verified");
  } catch {
    status.textContent = "The verified fact sheet is not available yet, so Ask AI is turned off.";
    form.querySelectorAll("input, button").forEach((e) => (e.disabled = true));
    loadBtn.disabled = true;
    return;
  }
  index = buildIndex(kb);
  factById = new Map(kb.facts.map((f) => [f.id, f]));
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

async function modelAnswer(question, facts, proofs) {
  const { pipe, TextStreamer } = generator;
  const div = bubble("bot", "ai-draft");
  const body = el("p");
  div.append(el("p", "ai-note", "Unchecked draft"), body);
  let draft = "";
  const streamer = new TextStreamer(pipe.tokenizer, {
    skip_prompt: true,
    skip_special_tokens: true,
    callback_function: (t) => { draft += t; body.textContent = draft; log.scrollTop = log.scrollHeight; },
  });
  const out = await pipe(buildMessages(kb, facts, proofs, history.slice(-4), question), {
    max_new_tokens: 320, do_sample: false, streamer,
  });
  const answer = (out[0].generated_text.at(-1).content || draft).trim();
  const v = verifyAnswer(answer, kb);
  div.remove();
  if (v.ok) {
    renderChecked(v.parts);
    history.push({ role: "user", content: question }, { role: "assistant", content: answer });
  } else {
    const shown = proofs.length && !facts.length
      ? proofsBubble(proofs, "I could not verify my answer, so here are the relevant Lean proofs:")
      : factsBubble(facts.slice(0, 3), "I could not verify my answer, so here is what the verified facts say:");
    note(shown, "Withheld: the draft was not quoted word for word from the facts it cited.", "ai-bad");
  }
}

async function ask(question) {
  question = question.trim();
  if (!question || !kb) return;
  bubble("user").textContent = question;
  input.value = "";
  // Short follow-ups ("tell me more") reuse the previous question for retrieval.
  let facts = retrieve(index, question, 5);
  if (facts.length < 2 && lastQuestion) facts = retrieve(index, question + " " + lastQuestion, 5);
  const proofs = retrieveProofs(kb, question);
  lastQuestion = question;
  if (!facts.length && !proofs.length) {
    if (isVague(question)) clarify();
    else bubble("bot").textContent = kb.templates.unknown;
    return;
  }
  if (!generator) {
    if (proofs.length) proofsBubble(proofs, "From the Lean proofs:");
    else factsBubble(facts.slice(0, 3), "From the verified facts:");
    try { await loadModel(); } catch { return; }
  }
  try {
    form.querySelector("button").disabled = true;
    await modelAnswer(question, facts, proofs);
  } catch (e) {
    console.warn("Ask AI: generation failed", e);
    bubble("bot").textContent = "Something went wrong while writing an answer. The verified facts above still apply.";
  } finally {
    form.querySelector("button").disabled = false;
  }
}

form.addEventListener("submit", (e) => { e.preventDefault(); ask(input.value); });
loadBtn.addEventListener("click", () => loadModel().catch(() => {}));
document.querySelectorAll(".ai-chip").forEach((b) => b.addEventListener("click", () => ask(b.textContent)));
init();
