"""Build the LoRA training data for Ask Zac AI from the Lean-checked fact sheet.

Reads zac_kb.json (written by the Lean exporter, Main.lean) and writes train.jsonl and valid.jsonl
in the chat format mlx_lm.lora expects. Every answer is copied from a verified fact or
is a fixed refusal, so the model is only ever trained on Lean-checked text.

Usage: python3 build_dataset.py --kb ../zac_kb.json --out ~/zac-lm-build/data
"""
import argparse
import json
import random
from pathlib import Path

VALID_FRACTION = 0.1
MAX_ANSWER_CHARS = 1100  # about 320 tokens, the answer limit on the website
EMAIL = "zacnburton@gmail.com"

# Questions per fact id. Each answer is that fact's text.
QUESTIONS = {
    "identity": ["Who is Zac?", "Tell me about Zac Burton.", "Who is Zachary Burton?", "Give me a quick intro to Zac.", "What's Zac's background?", "Where is Zac from?"],
    "pramaana": ["What does Zac do now?", "Where does Zac work?", "What is Zac researching at Pramaana?", "What is Zac's current job?", "What is Pramaana Labs?", "When did Zac join Pramaana?"],
    "meta-mle": ["What did Zac do at Meta?", "Did Zac work at Meta full time?", "What was Zac's job before Pramaana?", "What did Zac work on in Reels?", "When was Zac at Meta as an engineer?"],
    "meta-intern": ["Did Zac intern anywhere?", "What was Zac's Meta internship?", "What did Zac do on Rights Manager?", "Tell me about the copyright work at Meta."],
    "mit": ["Where did Zac go to college?", "What did Zac study at MIT?", "What was Zac's GPA?", "When did Zac graduate?", "What degree does Zac have?"],
    "tonbridge": ["Where did Zac go to school before MIT?", "What A-Levels did Zac take?", "Tell me about Tonbridge.", "What were Zac's A-Level grades?"],
    "contact": ["How can I contact Zac?", "What is Zac's email?", "Is Zac on GitHub?", "Where can I find Zac online?", "What's Zac's LinkedIn?"],
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
    "pieface": ["What is PIEFACE?", "Tell me about Zac's RLHF platform."],
    "zos": ["What is zOS?", "What has Zac built in Rust?"],
    "fcs": ["What is Formal Complexity Science?", "Has Zac formalized anything in Lean?"],
    "nanoalphatensor": ["What is nanoAlphaTensor?", "Did Zac reproduce AlphaTensor?"],
    "overtone": ["What is Overtone?", "Has Zac built a music app?"],
    "polisci": ["What is the political persuasion paper?", "Did Zac study AI and misinformation?"],
    "scribe": ["What is Scribe AI?", "What did Zac build at HackMIT?"],
    "edu-despite-ai": ["What is Education Despite AI?", "Has Zac written about AI in education?"],
    "courses-math": ["What math classes did Zac take?", "What grades did Zac get in math?", "Did Zac take real analysis?"],
    "courses-other": ["What classes did Zac take at MIT?", "Did Zac take any graduate courses?", "Did Zac take acting classes?"],
    "teaching": ["Has Zac taught?", "What teaching has Zac done?", "What did Zac teach in Peru?", "Was Zac a TA?"],
    "eloranta": ["What was Zac's Eloranta proposal?", "Has Zac worked on math education?"],
    "leadership": ["What clubs was Zac in at MIT?", "What leadership roles did Zac have?"],
    "honors": ["What awards has Zac won?", "What are Zac's honors?"],
    "athletics": ["Does Zac run track?", "What sports does Zac play?", "How fast is Zac?"],
    "talks": ["Has Zac given talks?", "Where can I watch Zac speak?"],
    "music": ["Does Zac sing?", "What are Zac's musical interests?", "Does Zac play an instrument?"],
    "interests": ["What does Zac do for fun?", "What is Zac interested in outside work?"],
}

# Questions per fact group (groups are defined in lean/ZacFacts/Data.lean). Each answer
# is the group's facts joined in order, so it is still made only of verified text.
GROUP_QUESTIONS = {
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

FOLLOW_UPS = ["Tell me more.", "What else?", "Anything else related?", "And before that?"]

PRIVATE = ["What is Zac's home address?", "How much does Zac earn?", "What is Zac's salary?", "Is Zac in a relationship?",
           "Who are Zac's roommates?", "What is Zac's phone number?", "Does Zac have any health conditions?",
           "How much student debt does Zac have?", "Who does Zac text the most?", "Where is Zac interviewing?"]
UNKNOWN = ["What is Bellman?", "Is Zac building a startup?", "What is Baller?", "What is Zac's favourite food?",
           "Will Zac do a PhD?", "What is Zac's opinion on Python vs Rust?", "Who is Zac's manager?",
           "Is Zac moving?", "What is Zac working on next year?", "Does Zac have a pet?"]
PRIVATE_ANSWER = (f"I only share public information about Zac's work, research, projects, and interests. "
                  f"For anything else, you can email Zac at {EMAIL}.")
UNKNOWN_ANSWER = f"I do not have verified information about that. You can email Zac at {EMAIL}."


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

    rng = random.Random(0)
    ids = list(facts)

    def context(*must):
        # Mirrors retrieval at inference: the relevant facts plus distractors, up to 5 in all.
        picked = list(must) + rng.sample([i for i in ids if i not in must], max(2, 5 - len(must)))
        rng.shuffle(picked)
        return kb["system_prompt"].replace("{facts}", "\n".join("- " + facts[i]["text"] for i in picked))

    examples = []
    for fid, qs in QUESTIONS.items():
        for q in qs:
            if q in combined_qs:
                continue  # answered with the whole group below
            for v in rng.sample(variants(q), 3):
                examples.append([("system", context(fid)), ("user", v), ("assistant", facts[fid]["text"])])
    # Combined answers: questions that need several facts get all of them, in group order.
    for gid, qs in GROUP_QUESTIONS.items():
        answer = " ".join(facts[i]["text"] for i in groups[gid])
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
                         ("assistant", facts[first]["text"]), ("user", rng.choice(FOLLOW_UPS)),
                         ("assistant", facts[second]["text"])])
    for q in PRIVATE:
        for v in rng.sample(variants(q), 3):
            examples.append([("system", context()), ("user", v), ("assistant", PRIVATE_ANSWER)])
    for q in UNKNOWN:
        for v in rng.sample(variants(q), 3):
            examples.append([("system", context()), ("user", v), ("assistant", UNKNOWN_ANSWER)])

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
