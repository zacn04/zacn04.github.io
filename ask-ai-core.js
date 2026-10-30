// Core logic for the Ask AI tab: retrieval over the Lean-checked fact sheet, prompt
// building, and the check every answer must pass before it is shown.
// No DOM access here, so it can be tested in Node.

const STOP = new Set(("a an and are as at be by did do does for from has have he her his how i in " +
  "is it its me my of on or she so tell that the their them they this to was were what when where " +
  "which who why with you your zac zac's zachary burton about s t re ll ve d m").split(" "));

// Words that carry no topic. A question made only of these is too vague to answer.
const VAGUE = new Set(("anything something stuff things thing interesting highlights give start " +
  "should can could would up else hi hello hey know more much lot like want tell everything all " +
  "doing done").split(" "));

export function words(text) {
  return text.toLowerCase().match(/[a-z0-9][a-z0-9.+*/-]*[a-z0-9+*]|[a-z0-9]/g) || [];
}

function terms(text) {
  return words(text).filter((w) => !STOP.has(w));
}

// True when every word is topic-free ("What did Zac do?", "Hi"). Callers should only treat
// a question as vague when retrieval also found no facts for it.
export function isVague(query) {
  return terms(query).every((w) => VAGUE.has(w));
}

// Sentences, split the same way as in _zac_lm/build_dataset.py: after . ! or ? (but not
// "..."), before a capital letter or a quote.
export function splitSentences(text) {
  return text.trim().split(/(?<=[^.][.!?])\s+(?=[A-Z"])/).filter(Boolean);
}

function norm(s) {
  return s.replace(/[\u2018\u2019]/g, "'").replace(/[\u201c\u201d]/g, '"').replace(/\s*\u2014\s*/g, ", ")
    .replace(/\s+/g, " ").trim();
}

// BM25 index over each fact's text and keywords (keywords count twice).
export function buildIndex(kb) {
  const docs = kb.facts.map((f) => terms(f.text + " " + f.keywords.join(" ") + " " + f.keywords.join(" ")));
  const df = new Map();
  for (const d of docs) for (const t of new Set(d)) df.set(t, (df.get(t) || 0) + 1);
  const avg = docs.reduce((s, d) => s + d.length, 0) / docs.length;
  return { kb, docs, df, avg, n: docs.length };
}

function escapeRe(t) {
  return t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Fact groups whose trigger phrase appears in the question, most specific (longest
// matching trigger) first.
export function matchGroups(kb, query) {
  const q = query.toLowerCase().replace(/[\u2018\u2019]/g, "'");
  const hits = [];
  for (const g of kb.groups || []) {
    let best = 0;
    for (const t of g.triggers) if (new RegExp("\\b" + escapeRe(t) + "\\b").test(q)) best = Math.max(best, t.length);
    if (best) hits.push([best, g]);
  }
  return hits.sort((a, b) => b[0] - a[0]).map((h) => h[1]);
}

// Facts for a question: any matched group's facts first, then BM25 results.
export function retrieve(index, query, k = 5) {
  const byId = new Map(index.kb.facts.map((f) => [f.id, f]));
  const out = [];
  for (const g of matchGroups(index.kb, query)) for (const id of g.facts) if (!out.includes(id)) out.push(id);
  for (const f of bm25(index, query, k)) if (!out.includes(f.id)) out.push(f.id);
  return out.slice(0, k).map((id) => byId.get(id));
}

function bm25(index, query, k) {
  const q = new Set(terms(query));
  const phrases = query.toLowerCase();
  const scored = index.docs.map((d, i) => {
    let s = 0;
    const tf = new Map();
    for (const t of d) tf.set(t, (tf.get(t) || 0) + 1);
    for (const t of q) {
      const f = tf.get(t);
      if (!f) continue;
      const idf = Math.log(1 + (index.n - index.df.get(t) + 0.5) / (index.df.get(t) + 0.5));
      s += idf * (f * 2.2) / (f + 1.2 * (0.25 + 0.75 * d.length / index.avg));
    }
    // Multi-word keywords ("track and field") score when the whole phrase appears.
    for (const kw of index.kb.facts[i].keywords) if (kw.includes(" ") && phrases.includes(kw)) s += 3;
    return { fact: index.kb.facts[i], score: s };
  });
  return scored.filter((x) => x.score > 0).sort((a, b) => b.score - a.score).slice(0, k).map((x) => x.fact);
}

// Questions asking how something is known get the most relevant Lean proofs.
const PROOF_INTENT = /\b(prove[sd]?|proofs?|proven|verif(?:y|ied|ies)|how do (?:you|we) know|formally)\b/i;

export function retrieveProofs(kb, query, k = 3) {
  if (!PROOF_INTENT.test(query)) return [];
  const q = new Set(terms(query));
  return (kb.proofs || [])
    .map((p) => ({ p, score: terms(p.doc + " " + p.name.replace(/_/g, " ")).filter((t) => q.has(t)).length }))
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, k)
    .map((x) => x.p);
}

export function systemMessage(kb, facts, proofs = []) {
  const lines = [...facts.map((f) => `- [${f.id}] ${f.text}`), ...proofs.map((p) => `- [proof:${p.name}] ${p.doc}`)];
  return kb.system_prompt.replace("{facts}", lines.join("\n"));
}

// Chat messages for the model: system prompt with retrieved facts and proofs, prior
// turns, then the question.
export function buildMessages(kb, facts, proofs, history, question) {
  return [{ role: "system", content: systemMessage(kb, facts, proofs) }, ...history, { role: "user", content: question }];
}

const TAG_RE = /\[(proof:)?([a-z0-9_-]+)\]/g;

// The check. An answer is accepted only if it is made entirely of:
//   - sentences copied word for word from a Lean-verified fact, followed by that fact's
//     id in brackets, like "... in February 2026. [mit]";
//   - the proof template followed by the id of a theorem the Lean kernel checked;
//   - one of the fixed template replies.
// Anything else (a paraphrase, a wrong citation, an invented sentence) fails.
// Returns the answer split into parts so the page can render citations and proofs.
export function verifyAnswer(answer, kb) {
  const text = norm(answer);
  const factSentences = new Map(kb.facts.map((f) => [f.id, new Set(splitSentences(f.text).map(norm))]));
  const proofNames = new Set((kb.proofs || []).map((p) => p.name));
  const templateSentences = new Set(Object.values(kb.templates || {}).flatMap((t) => splitSentences(t).map(norm)));
  const sentencesOf = (s) => splitSentences(s).map(norm).filter(Boolean);
  const parts = [];
  const problems = [];
  const needTemplates = (sents) => {
    for (const s of sents) if (!templateSentences.has(s)) problems.push(s);
    if (sents.length) parts.push({ type: "text", sentences: sents });
  };
  let last = 0;
  for (const m of text.matchAll(TAG_RE)) {
    const before = sentencesOf(text.slice(last, m.index));
    last = m.index + m[0].length;
    if (m[1]) {
      needTemplates(before);
      if (proofNames.has(m[2])) parts.push({ type: "proof", name: m[2] });
      else problems.push(m[0]);
      continue;
    }
    const allowed = factSentences.get(m[2]);
    if (!allowed) { problems.push(m[0]); continue; }
    if (!before.length) problems.push(`${m[0]} cites nothing`);
    for (const s of before) if (!allowed.has(s)) problems.push(s);
    parts.push({ type: "cite", id: m[2], sentences: before });
  }
  needTemplates(sentencesOf(text.slice(last)));
  if (!parts.length) problems.push("(empty answer)");
  return { ok: problems.length === 0, parts, problems };
}
