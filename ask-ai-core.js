// Core logic for the Ask AI tab: retrieval over the Lean-checked fact sheet, prompt
// building, and the check every answer must pass before it is shown.
// No DOM access here, so it can be tested in Node.

const STOP = new Set(("a an and are as at be by did do does for from has have he her his how i in " +
  "is it its me my of on or she so tell that the their them they this to was were what when where " +
  "which who why with you your zac zac's zachary burton about").split(" "));

// Organisations a small model might invent. Mentioning one is only allowed if the fact
// sheet (or the question) mentions it too.
const WATCHLIST = ["google", "deepmind", "openai", "anthropic", "microsoft", "apple", "amazon",
  "nvidia", "harmonic", "stanford", "harvard", "oxford", "cambridge", "princeton", "yale",
  "berkeley", "caltech", "imperial", "goldman", "jane street", "two sigma", "citadel", "netflix",
  "tesla", "spacex", "ibm", "intel", "uber", "airbnb", "stripe"];

export function words(text) {
  return text.toLowerCase().match(/[a-z0-9][a-z0-9.+*/-]*[a-z0-9+*]|[a-z0-9]/g) || [];
}

function terms(text) {
  return words(text).filter((w) => !STOP.has(w));
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

export function systemMessage(kb, facts) {
  return kb.system_prompt.replace("{facts}", facts.map((f) => "- " + f.text).join("\n"));
}

// Chat messages for the model: system prompt with retrieved facts, prior turns, question.
export function buildMessages(kb, facts, history, question) {
  return [{ role: "system", content: systemMessage(kb, facts) }, ...history, { role: "user", content: question }];
}

const URL_RE = /\bhttps?:\/\/[^\s<>()"']+/gi;
const EMAIL_RE = /\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b/gi;
const BARE_DOMAIN_RE = /\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|ai|net|org|edu|io|me)\b(?:\/[^\s<>()"']*)?/gi;
const NUM_RE = /\d+(?:[.,]\d+)*/g;
const MONTH_YEAR_RE = /\b(?:january|february|march|april|may|june|july|august|september|october|november|december) \d{4}\b/gi;

function normLink(s) {
  return s.toLowerCase().replace(/^https?:\/\//, "").replace(/^www\./, "").replace(/[.,;:!?)\]'"]+$/, "").replace(/\/$/, "");
}

function normNum(s) {
  return s.replace(/,(?=\d{3}\b)/g, "").replace(/[.,]$/, "");
}

// Claims in a piece of text: links, emails, month-year dates, and numbers. Links are
// removed before numbers are read, so the digits inside a URL are not counted twice.
export function extractClaims(text) {
  const links = new Set();
  const dates = new Set((text.match(MONTH_YEAR_RE) || []).map((d) => d.toLowerCase()));
  let rest = text.replace(URL_RE, (m) => { links.add(normLink(m)); return " "; });
  rest = rest.replace(EMAIL_RE, (m) => { links.add(m.toLowerCase()); return " "; });
  rest = rest.replace(BARE_DOMAIN_RE, (m) => { links.add(normLink(m)); return " "; });
  const numbers = new Set((rest.match(NUM_RE) || []).map(normNum));
  return { links, numbers, dates };
}

// Everything the fact sheet allows an answer to say.
export function allowedClaims(kb) {
  const links = new Set();
  const numbers = new Set();
  const dates = new Set();
  for (const f of kb.facts) {
    const c = extractClaims(f.text);
    c.links.forEach((l) => links.add(l));
    c.numbers.forEach((n) => numbers.add(n));
    c.dates.forEach((d) => dates.add(d));
  }
  const haystack = kb.facts.map((f) => f.text.toLowerCase()).join(" \n ");
  return { links, numbers, dates, haystack };
}

export function cleanAnswer(text) {
  return text.replace(/\s*\u2014\s*/g, ", ").trim();
}

// An answer passes if every number, link, month-year date, and watched organisation in
// it appears in the Lean-checked facts (or in the visitor's own question), and it avoids
// blocked terms. A true value used in the wrong context (a real date attached to the wrong
// role) is not caught.
export function verifyAnswer(answer, kb, allowed, question = "") {
  const fromQuestion = extractClaims(question);
  const c = extractClaims(answer);
  const unverified = [];
  for (const n of c.numbers) if (!allowed.numbers.has(n) && !fromQuestion.numbers.has(n)) unverified.push(n);
  for (const l of c.links) if (!allowed.links.has(l) && !fromQuestion.links.has(l)) unverified.push(l);
  for (const d of c.dates) if (!allowed.dates.has(d) && !fromQuestion.dates.has(d)) unverified.push(d);
  const low = answer.toLowerCase();
  const q = question.toLowerCase();
  for (const org of WATCHLIST) {
    const re = new RegExp("\\b" + org + "\\b");
    if (re.test(low) && !re.test(allowed.haystack) && !re.test(q)) unverified.push(org);
  }
  const blocked = kb.blocklist.filter((b) => low.includes(b));
  return { ok: unverified.length === 0 && blocked.length === 0, unverified, blocked };
}
