"""Build the LoRA training data for Ask Zac AI from the Lean-checked fact sheet.

Reads zac_kb.json (written by the Lean exporter, Main.lean) and writes train.jsonl and valid.jsonl
in the chat format mlx_lm.lora expects. Every answer is either sentences copied from
verified facts with the fact's id in brackets ("... [mit]"), a Lean proof id
("This is proved in Lean: [proof:name]"), or a fixed template reply, so the model is
only ever trained on Lean-checked text, in the exact form the website's checker accepts.

Usage: python3 build_dataset.py --kb ../zac_kb.json --out ~/zac-lm-build/data
"""
import argparse
import json
import random
import re
from pathlib import Path

VALID_FRACTION = 0.1
MAX_ANSWER_CHARS = 1100  # about 320 tokens, the answer limit on the website

# Questions per fact id. Each answer cites that fact: all of its sentences, or only the
# ones listed in SENTENCES for that question.
QUESTIONS = {
    "identity": ["Who is Zac?", "Tell me about Zac Burton.", "Who is Zachary Burton?", "Give me a quick intro to Zac.", "What's Zac's background?", "Where is Zac from?"],
    "pramaana": ["What does Zac do now?", "Where does Zac work?", "What is Zac researching at Pramaana?", "What is Zac's current job?", "What is Pramaana Labs?", "When did Zac join Pramaana?", "What does Zac work on at Pramaana?"],
    "meta-mle": ["What did Zac do at Meta?", "Did Zac work at Meta full time?", "What was Zac's job before Pramaana?", "What did Zac work on in Reels?", "When was Zac at Meta as an engineer?", "What was Zac's role at Meta in 2026?"],
    "meta-intern": ["Did Zac intern anywhere?", "What was Zac's Meta internship?", "What did Zac do on Rights Manager?", "Tell me about the copyright work at Meta.", "When did Zac intern at Meta?"],
    "mit": ["Where did Zac go to college?", "What did Zac study at MIT?", "What was Zac's GPA?", "What grades did Zac get?", "When did Zac graduate?", "What degree does Zac have?"],
    "tonbridge": ["Where did Zac go to school before MIT?", "What A-Levels did Zac take?", "Tell me about Tonbridge.", "What were Zac's A-Level grades?"],
    "contact": ["How can I contact Zac?", "What is Zac's email?", "Is Zac on GitHub?", "Where can I find Zac online?", "What's Zac's LinkedIn?", "What is Zac's website?"],
    "paper-lean": ["Summarize Zac's ICML 2026 workshop paper.", "What is Zac's first-author paper?", "Where can I read the Lean provers paper?", "Is there code for the Lean paper?", "What did Zac publish at the AI4Math workshop?"],
    "paper-lean-results": ["What did the Lean provers paper find?", "What is mode collapse in Lean provers?", "What happens when you double the sampling budget?", "How do tactic skeletons help?", "What were the miniF2F results?"],
    "qedbench": ["What is QEDBench?", "Did Zac publish at the ICML main conference?", "Who led QEDBench?", "Where can I read QEDBench?"],
    "qedbench-role": ["What did Zac do on QEDBench?", "What proof mistakes do LLMs make?", "What failure modes did Zac find in LLM proofs?", "What areas did Zac grade for QEDBench?"],
    "neg-transfer": ["Does visual reasoning training help math?", "What is the negative transfer study?", "What happened on MATH-500?", "Tell me about the Qwen2.5-VL-7B study.", "Why did math scores drop?"],
    "dyck": ["What did the pretraining experiment show?", "What is the Dyck warm-up result?", "Did Zac pretrain a model from scratch?"],
    "collision": ["What is Zac's random walks paper?", "Tell me about the collision threshold preprint.", "Has Zac done pure math research?"],
    "tabular-rl": ["What is the tabular RL blog post?", "Does Zac have a blog?", "Where does tabular RL break?"],
    "research-interests": ["What are Zac's research interests?", "What does Zac research?", "What topics is Zac exploring?"],
    "csail": ["What did Zac do at CSAIL?", "Did Zac do undergraduate research?", "What was the FutureTech project?"],
    "cfar": ["What did Zac do in Singapore?", "What is SIPGA?", "Where did Zac research after freshman year?"],
    "service": ["Does Zac review papers?", "What academic service does Zac do?"],
    "sprintgame": ["What is the sprintgame?", "Tell me about SPRINT.", "Did Zac make a game?", "How many people play the sprintgame?"],
    "sprintgame-engine": ["How does the SPRINT game engine work?", "How are races simulated in the sprintgame?", "What are the genetic dials?"],
    "pieface": ["What is PIEFACE?", "Tell me about Zac's RLHF platform.", "What is PIEFACE built with?"],
    "zos": ["What is zOS?", "What has Zac built in Rust?"],
    "fcs": ["What is Formal Complexity Science?", "Has Zac formalized anything in Lean?"],
    "nanoalphatensor": ["What is nanoAlphaTensor?", "Did Zac reproduce AlphaTensor?"],
    "overtone": ["What is Overtone?", "Has Zac built a music app?"],
    "polisci": ["What is the political persuasion paper?", "Did Zac study AI and misinformation?"],
    "scribe": ["What is Scribe AI?", "What did Zac build at HackMIT?"],
    "edu-despite-ai": ["What is Education Despite AI?", "Has Zac written about AI in education?"],
    "courses-math": ["What math classes did Zac take?", "Which math courses did Zac take?", "Did Zac take real analysis?"],
    "courses-other": ["What classes did Zac take at MIT?", "Did Zac take any graduate courses?", "Did Zac take acting classes?", "Did Zac take classes at Harvard?"],
    "teaching": ["Has Zac taught?", "What teaching has Zac done?", "What did Zac teach in Peru?", "Was Zac a TA?"],
    "eloranta": ["What was Zac's Eloranta proposal?", "Has Zac worked on math education?"],
    "leadership": ["What clubs was Zac in at MIT?", "What leadership roles did Zac have?", "Was Zac on the class council?"],
    "honors": ["What awards has Zac won?", "What are Zac's honors?"],
    "athletics": ["Does Zac run track?", "What sports does Zac play?", "How fast is Zac?"],
    "talks": ["Has Zac given talks?", "Where can I watch Zac speak?"],
    "music": ["Does Zac sing?", "What are Zac's musical interests?", "Does Zac play an instrument?"],
    "interests": ["What does Zac do for fun?", "What is Zac interested in outside work?"],
}

# Short answers: for these questions, cite only the listed sentences (0-based) of the fact.
SENTENCES = {
    "When did Zac join Pramaana?": [0], "What does Zac work on at Pramaana?": [1],
    "What was Zac's role at Meta in 2026?": [0], "When was Zac at Meta as an engineer?": [0],
    "What did Zac work on in Reels?": [1],
    "When did Zac intern at Meta?": [0], "What did Zac do on Rights Manager?": [1],
    "Where is Zac from?": [1],
    "What is Zac's email?": [0], "Is Zac on GitHub?": [1], "What's Zac's LinkedIn?": [2], "What is Zac's website?": [3],
    "Where can I read the Lean provers paper?": [1], "Is there code for the Lean paper?": [2],
    "What is mode collapse in Lean provers?": [0], "What happens when you double the sampling budget?": [1],
    "How do tactic skeletons help?": [2],
    "Where can I read QEDBench?": [1], "Who led QEDBench?": [0],
    "What proof mistakes do LLMs make?": [1], "What failure modes did Zac find in LLM proofs?": [1],
    "What areas did Zac grade for QEDBench?": [0],
    "What happened on MATH-500?": [1], "Why did math scores drop?": [2],
    "What are Zac's research interests?": [0],
    "How many people play the sprintgame?": [2], "What are the genetic dials?": [1],
    "What is PIEFACE built with?": [1],
    "Did Zac take classes at Harvard?": [1],
    "What did Zac teach in Peru?": [0], "Was Zac a TA?": [1],
    "Was Zac on the class council?": [0],
    "Does Zac sing?": [0], "Does Zac play an instrument?": [1],
}

# Questions per fact group (groups are defined in lean/ZacFacts/Data.lean). The answer
# cites each of the group's facts in order: the first sentence of each, or every
# sentence for the groups in FULL_GROUPS.
GROUP_QUESTIONS = {
    "identity": ["Who is Zac?", "Tell me about Zac Burton.", "Who is Zachary Burton?", "Give me a quick intro to Zac."],
    "publications": ["Summarize Zac's ICML 2026 papers", "What has Zac published?", "What are Zac's publications?", "What papers has Zac written?", "What are Zac's ICML papers?"],
    "lean-paper": ["Tell me everything about the Lean provers paper", "Explain Zac's first-author paper and its results", "What is the Lean diversity paper about and what did it find?"],
    "qedbench": ["Tell me about QEDBench and Zac's role in it", "What is QEDBench and what did Zac contribute?"],
    "transfer": ["Explain the visual reasoning transfer study in full", "What were all the results of the transfer study?", "Tell me about the negative transfer and Dyck experiments"],
    "career": ["Where has Zac worked?", "What is Zac's work history?", "Walk me through Zac's career", "What jobs has Zac had?"],
    "meta": ["What did Zac do at Meta?", "Tell me about both of Zac's Meta roles"],
    "education": ["What is Zac's education?", "Where did Zac study?", "Tell me about Zac's schooling"],
    "lean": ["What has Zac done with Lean?", "Tell me about Zac's formal methods work", "Does Zac work on theorem proving?"],
    "rl": ["What reinforcement learning research has Zac done?", "What RL work has Zac done?"],
    "undergrad-research": ["What research did Zac do as an undergraduate?", "Tell me about Zac's research experience"],
    "sprintgame": ["Tell me everything about the sprintgame", "How does the sprintgame work and who plays it?"],
    "projects": ["What projects has Zac built?", "What has Zac built?", "Show me Zac's side projects"],
    "ml-projects": ["What ML projects has Zac built?", "Has Zac built anything with language models?"],
    "courses": ["What courses did Zac take?", "Tell me about Zac's MIT coursework"],
    "teaching": ["What teaching and education work has Zac done?", "How is Zac involved in education?"],
    "outside-work": ["What does Zac do outside of research?", "What are Zac's hobbies?", "What is Zac like outside work?"],
    "awards": ["What awards has Zac won?", "What are Zac's achievements outside academics?"],
    "ai-society": ["What has Zac written about AI and society?", "Has Zac studied AI ethics or politics?"],
    "math-research": ["What math research has Zac done?", "Has Zac done mathematical research?"],
    "current-focus": ["What is Zac researching now and what interests Zac?", "What is Zac's current research focus?"],
}

FULL_GROUPS = {"identity", "lean-paper", "qedbench", "transfer", "sprintgame", "courses", "teaching"}

# Questions answered with a Lean proof. Each must ask how something is known (the
# website only offers proofs to questions like that).
PROOF_QUESTIONS = {
    "months_valid": ["Are the dates in Zac's fact sheet verified?", "Can you prove the role dates are real months?"],
    "roles_ordered": ["Can you prove every role ends after it starts?", "How do you know Zac's role dates are in order?"],
    "roles_not_in_future": ["How do you know no role starts in the future?", "Prove that no role starts after the fact sheet's date."],
    "intern_during_mit": ["How do you know the Meta internship was during MIT?", "Prove Zac interned at Meta while at MIT."],
    "csail_during_mit": ["How do you know the CSAIL research was during MIT?", "Prove the CSAIL research happened while Zac was at MIT."],
    "graduated_before_meta": ["How do you know Zac graduated before joining Meta?", "Prove Zac finished MIT before working at Meta full time."],
    "meta_before_pramaana": ["How do you know Zac left Meta before Pramaana?", "Prove Zac left Meta before joining Pramaana."],
    "only_pramaana_current": ["How do you know Pramaana is Zac's only current job?", "Prove Pramaana is Zac's only current role."],
    "neg_transfer_all_negative": ["How do you know every transfer condition was negative?", "Prove the transfer study showed negative transfer."],
    "prover_budget_doubled": ["How do you know the sampling budget was doubled?", "Prove k=64 is double k=32."],
    "prover_plateau": ["How do you know doubling the budget solved nothing new?", "Prove the doubled budget solved 0 additional theorems."],
    "prover_gain_exceeds_sd": ["How do you know the tactic skeleton gain is real?", "Prove the gain is larger than its standard deviation."],
    "dyck_all_seeds": ["How do you know every Dyck seed improved?", "Prove the Dyck warm-up helped in every seed."],
    "gpa_in_range": ["How do you know Zac's GPA is valid?", "Prove Zac's GPA is on the 5.0 scale."],
}

# Too vague to answer: the reply asks which topic the visitor means.
VAGUE = ["What did Zac do?", "Tell me something.", "What's Zac up to?", "Anything interesting?",
         "What can you tell me?", "Give me the highlights.", "Where should I start?", "Hi", "Hello", "Tell me everything."]

FOLLOW_UPS = ["Tell me more.", "What else?", "Anything else related?", "And before that?"]

PRIVATE = ["What is Zac's home address?", "How much does Zac earn?", "What is Zac's salary?", "Is Zac in a relationship?",
           "Who are Zac's roommates?", "What is Zac's phone number?", "Does Zac have any health conditions?",
           "How much student debt does Zac have?", "Who does Zac text the most?", "Where is Zac interviewing?"]
UNKNOWN = ["What is Bellman?", "Is Zac building a startup?", "What is Baller?", "What is Zac's favourite food?",
           "Will Zac do a PhD?", "What is Zac's opinion on Python vs Rust?", "Who is Zac's manager?",
           "Is Zac moving?", "What is Zac working on next year?", "Does Zac have a pet?"]


def split_sentences(text):
    # Same rule as splitSentences in ask-ai-core.js: after . ! or ? (but not "..."),
    # before a capital letter or a quote.
    return [s for s in re.split(r'(?<=[^.][.!?])\s+(?=[A-Z"])', text.strip()) if s]


def variants(q):
    base = q.rstrip("?.")
    low = base[0].lower() + base[1:]
    return [q, q.lower(), base, f"Can you tell me: {low}?", f"Quick question: {q}", f"Hey, {low}?",
            f"I'm curious, {low}?", f"{base}, in a few sentences?", f"Do you know {low}?"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--allow-unverified", action="store_true", help="testing only")
    a = ap.parse_args()
    kb = json.loads(Path(a.kb).read_text())
    if kb.get("verifier") != "lean" and not a.allow_unverified:
        raise SystemExit("zac_kb.json was not written by the Lean exporter. Run bash _zac_lm/train.sh first.")
    facts = {f["id"]: f for f in kb["facts"]}
    missing = set(facts) ^ set(QUESTIONS)
    if missing:
        raise SystemExit(f"QUESTIONS and the fact sheet disagree on: {sorted(missing)}")
    groups = {g["id"]: g["facts"] for g in kb.get("groups", [])}
    missing = set(groups) ^ set(GROUP_QUESTIONS)
    if missing:
        raise SystemExit(f"GROUP_QUESTIONS and the fact groups disagree on: {sorted(missing)}")
    combined_qs = {q for qs in GROUP_QUESTIONS.values() for q in qs}
    proofs = {p["name"]: p for p in kb.get("proofs", [])}
    missing = set(proofs) ^ set(PROOF_QUESTIONS)
    if missing:
        raise SystemExit(f"PROOF_QUESTIONS and the Lean proofs disagree on: {sorted(missing)}")
    templates = kb["templates"]
    for q in SENTENCES:
        if not any(q in qs for qs in QUESTIONS.values()):
            raise SystemExit(f"SENTENCES lists a question that is not in QUESTIONS: {q}")

    def cite(fid, which=None):
        sents = split_sentences(facts[fid]["text"])
        chosen = sents if which is None else [sents[i] for i in which]
        return " ".join(chosen) + f" [{fid}]"

    rng = random.Random(0)
    ids = list(facts)

    def context(*must, proof=None):
        # Mirrors the website: up to 5 facts as "- [id] text" (the relevant ones plus
        # distractors, shuffled), then any proofs as "- [proof:name] description".
        picked = list(must) + rng.sample([i for i in ids if i not in must], max(2, 5 - len(must)))
        rng.shuffle(picked)
        lines = [f"- [{i}] {facts[i]['text']}" for i in picked]
        if proof:
            names = [proof] + rng.sample([n for n in proofs if n != proof], 2)
            rng.shuffle(names)
            lines += [f"- [proof:{n}] {proofs[n]['doc']}" for n in names]
        return kb["system_prompt"].replace("{facts}", "\n".join(lines))

    examples = []
    for fid, qs in QUESTIONS.items():
        for q in qs:
            if q in combined_qs:
                continue  # answered with the whole group below
            for v in rng.sample(variants(q), 3):
                examples.append([("system", context(fid)), ("user", v), ("assistant", cite(fid, SENTENCES.get(q)))])
    # Combined answers: questions that need several facts cite each of them, in group order.
    for gid, qs in GROUP_QUESTIONS.items():
        answer = " ".join(cite(i, None if gid in FULL_GROUPS else [0]) for i in groups[gid])
        if len(answer) > MAX_ANSWER_CHARS:
            raise SystemExit(f"group {gid} answer is too long for the website's answer limit")
        for q in qs:
            for v in rng.sample(variants(q), 4):
                examples.append([("system", context(*groups[gid])), ("user", v), ("assistant", answer)])
    # Multi-turn: a follow-up moves to a related fact on the same topic.
    by_topic = {}
    for f in kb["facts"]:
        by_topic.setdefault(f["topic"], []).append(f["id"])
    for _ in range(100):
        topic = rng.choice([t for t, v in by_topic.items() if len(v) > 1])
        first, second = rng.sample(by_topic[topic], 2)
        examples.append([("system", context(first, second)), ("user", rng.choice(QUESTIONS[first])),
                         ("assistant", cite(first)), ("user", rng.choice(FOLLOW_UPS)),
                         ("assistant", cite(second))])
    for name, qs in PROOF_QUESTIONS.items():
        for q in qs:
            for v in rng.sample(variants(q), 3):
                examples.append([("system", context(proof=name)), ("user", v),
                                 ("assistant", f"{templates['proof']} [proof:{name}]")])
    for q in VAGUE:
        for v in rng.sample(variants(q), 2):
            examples.append([("system", context()), ("user", v), ("assistant", templates["clarify"])])
    for q in PRIVATE:
        for v in rng.sample(variants(q), 3):
            examples.append([("system", context()), ("user", v), ("assistant", templates["private"])])
    for q in UNKNOWN:
        for v in rng.sample(variants(q), 3):
            examples.append([("system", context()), ("user", v), ("assistant", templates["unknown"])])

    rng.shuffle(examples)
    rows = [{"messages": [{"role": r, "content": c} for r, c in ex]} for ex in examples]
    n_valid = max(1, round(len(rows) * VALID_FRACTION))

    # The same rules the Lean exporter enforces, rechecked on everything the model is
    # trained to read or say (visitor questions may contain blocked words, like "salary").
    said = " ".join(m["content"] for r in rows for m in r["messages"] if m["role"] != "user").lower()
    if "\u2014" in json.dumps(rows, ensure_ascii=False):
        raise SystemExit("em dash in generated data")
    for term in kb["blocklist"] + private_terms():
        if term.lower() in said:
            raise SystemExit(f"blocked term in generated data: {term!r}")

    out = Path(a.out).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    for name, part in (("train", rows[n_valid:]), ("valid", rows[:n_valid])):
        with open(out / f"{name}.jsonl", "w") as fh:
            for r in part:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"wrote {len(rows) - n_valid} train and {n_valid} valid examples to {out}")


def private_terms():
    p = Path(__file__).with_name("private_blocklist.txt")
    return [t.strip() for t in p.read_text().splitlines() if t.strip()] if p.exists() else []


if __name__ == "__main__":
    main()
