import ZacFacts.Basic

/-
The verified public fact sheet for Ask Zac AI.

This file is the single source of truth: the exporter (`Main.lean`) writes it to `zac_kb.json`,
which the training data and the website both read. Keep every fact public, and never
use em dashes. Write about Zac by name rather than with pronouns.
-/
namespace ZacFacts

def asOf : YM := ⟨2026, 10⟩

/-! ## Dated roles (checked in `Checks.lean`) -/

def mit : Role := { factId := "mit", start := ⟨2022, 9⟩, stop := ⟨2026, 2⟩ }
def csail : Role := { factId := "csail", start := ⟨2024, 11⟩, stop := ⟨2025, 8⟩ }
def metaIntern : Role := { factId := "meta-intern", start := ⟨2025, 5⟩, stop := ⟨2025, 8⟩ }
def metaMLE : Role := { factId := "meta-mle", start := ⟨2026, 2⟩, stop := ⟨2026, 8⟩ }
def pramaana : Role := { factId := "pramaana", start := ⟨2026, 9⟩, stop := asOf, current := true }

def roles : List Role := [mit, csail, metaIntern, metaMLE, pramaana]

/-! ## Numeric results (checked in `Checks.lean`) -/

/-- Visual reasoning to math transfer study. Scores are tenths of a percent on MATH-500. -/
structure NegTransfer where
  conditions : Nat
  base : Nat
  lo : Nat
  hi : Nat

def negTransfer : NegTransfer := { conditions := 8, base := 668, lo := 440, hi := 616 }

/-- Inference-time diversity paper. `gain` and `sd` are tenths of a theorem. -/
structure ProverStudy where
  kBefore : Nat
  kAfter : Nat
  extraSolved : Nat
  skeletons : Nat
  gain : Nat
  sd : Nat
  seeds : Nat

def proverStudy : ProverStudy :=
  { kBefore := 32, kAfter := 64, extraSolved := 0, skeletons := 15, gain := 123, sd := 42, seeds := 3 }

/-- From-scratch pretraining extension. `cut` is tenths of a percent. -/
structure DyckStudy where
  paramsM : Nat
  warmupPct : Nat
  cut : Nat
  seedsBetter : Nat
  seeds : Nat

def dyck : DyckStudy := { paramsM := 162, warmupPct := 1, cut := 123, seedsBetter := 3, seeds := 3 }

/-- MIT GPA in tenths, on a 5.0 scale. -/
def gpa : Nat := 46

/-! ## Facts -/

def facts : List Fact := [
  { id := "identity", topic := "about",
    keywords := ["who", "zac", "zachary", "burton", "about", "background", "intro", "bio"],
    text := "Zac Burton (Zachary Burton) is a research engineer at Pramaana Labs. Zac graduated from MIT in February 2026 with a B.S. in Mathematics, was born in New York City, was raised in the UK, and is based in Brooklyn, New York." },
  { id := "pramaana", topic := "work",
    keywords := ["pramaana", "job", "current", "work", "role", "now", "research engineer", "member of technical staff", "verification", "formalization"],
    text := "Since September 2026, Zac has been a Research Engineer (Member of Technical Staff, ML Research) at Pramaana Labs, which builds formal verification for high-stakes AI. Zac works on training models for theorem proving and autoformalization." },
  { id := "meta-mle", topic := "work",
    keywords := ["meta", "facebook", "reels", "ranking", "monetization", "machine learning engineer", "ic3", "previous", "industry"],
    text := "From February 2026 to August 2026, Zac was a Machine Learning Engineer (IC3) at Meta in New York, on Facebook Reels Ranking and Monetization. Zac evaluated the revenue impact of ranking-signal changes in the late-stage pipeline, designed offline experiments and metrics for the tradeoffs between revenue lift, engagement quality, and long-term user value, and proposed an architectural change to the core value model that enables signal-level backtesting." },
  { id := "meta-intern", topic := "work",
    keywords := ["meta", "intern", "internship", "copyright", "rights manager", "integrity", "software engineer"],
    text := "From May 2025 to August 2025, Zac was a Software Engineer Intern at Meta in New York, on Integrity and Copyright Enforcement (Rights Manager). Zac refactored a copyright policy evaluation engine that processes 2B+ uploads a day, reaching 97% consistency with the legacy outputs in 12 weeks, verified with SQL logging and an automated regression suite." },
  { id := "mit", topic := "education",
    keywords := ["mit", "education", "degree", "college", "university", "gpa", "grades", "mathematics", "course 18", "graduate", "graduated"],
    text := "Zac studied at MIT from September 2022 to February 2026 and earned a B.S. in Mathematics (Course 18) with a GPA of 4.6/5.0." },
  { id := "tonbridge", topic := "education",
    keywords := ["tonbridge", "school", "high school", "a-levels", "a levels", "uk", "secondary"],
    text := "Before MIT, Zac attended Tonbridge School in the UK from 2017 to 2022, earning A* grades in A-Level Mathematics, Further Mathematics, Physics, and Chemistry." },
  { id := "contact", topic := "contact",
    keywords := ["contact", "email", "reach", "github", "linkedin", "website", "links", "get in touch"],
    text := "You can email Zac at zacnburton@gmail.com or zburton@mit.edu. GitHub: https://github.com/zacn04. LinkedIn: https://linkedin.com/in/zac-burton. Website: https://zacburton.com." },
  { id := "paper-lean", topic := "research",
    keywords := ["icml", "lean", "theorem prover", "provers", "diversity", "inference-time", "paper", "papers", "first author", "ai4math", "workshop", "publication", "publications"],
    text := "Zac is first author of Inference-Time Diversity in RL-Trained Lean Theorem Provers: A Diagnostic Study, a poster at the ICML 2026 AI4Math Workshop (arXiv 2601.16172). Paper: https://zacburton.com/lean_diversity.pdf. Code: https://github.com/zacn04/icml_hints_for_provers." },
  { id := "paper-lean-results", topic := "research",
    keywords := ["mode collapse", "minif2f", "deepseek", "tactic", "skeletons", "results", "findings", "sampling", "omega", "aesop", "grind", "plateau"],
    text := "The Lean provers paper finds that RL-trained Lean 4 provers mode-collapse at inference time, favouring solver tactics such as omega, aesop, and grind. On miniF2F-test, doubling the sampling budget of DeepSeek-Prover-V1.5-RL from k=32 to k=64 solves 0 additional theorems. Prefixing a fixed schedule of 15 tactic skeletons breaks the plateau, adding 12.3 +/- 4.2 theorems across 3 seeds, and controlled ablations show that the gain comes from tactic structure rather than prompt diversity." },
  { id := "qedbench", topic := "research",
    keywords := ["qedbench", "icml", "main conference", "coauthor", "proofs", "evaluation", "yale", "quanquan liu", "benchmark", "llm judges", "papers", "publications"],
    text := "Zac is a coauthor of QEDBench: Quantifying the Alignment Gap in Automated Evaluation of University-Level Mathematical Proofs, a poster at the ICML 2026 main conference, with PI Quanquan Liu at Yale University. Paper: https://openreview.net/pdf?id=Rh7mc7FdGN." },
  { id := "qedbench-role", topic := "research",
    keywords := ["qedbench", "grading", "judgments", "error taxonomy", "failure modes", "partial credit", "proof errors", "contribution"],
    text := "For QEDBench, Zac produced gold-standard PhD-level correctness judgments, error taxonomies, and partial-credit assessments in probability, discrete mathematics, and algorithms. The failure modes Zac identified in LLM proofs include forcing in false inequalities labelled as elementary, presenting unmotivated formulaic identities such as alternating sums without explaining why they matter, skipping non-trivial steps, and appending unproved remarks." },
  { id := "neg-transfer", topic := "research",
    keywords := ["negative transfer", "visual reasoning", "qwen", "raven", "i-raven", "math-500", "grpo", "sft", "transfer", "pre-registered"],
    text := "Negative Transfer is the Default: Visual Reasoning to Math on Qwen2.5-VL-7B (2026) is a pre-registered study of whether post-training on abstract visual reasoning (I-RAVEN, Raven's progressive matrices) transfers to mathematical reasoning. All 8 matched-eval SFT and GRPO conditions showed negative transfer on MATH-500: the base model scored 66.8% and the trained models scored between 44.0% and 61.6%. The drop comes from completion compression rather than format failure." },
  { id := "dyck", topic := "research",
    keywords := ["dyck", "pretraining", "from scratch", "162m", "formal language", "warm-up", "compositional algebra"],
    text := "Zac extended the transfer study to from-scratch pretraining of a 162M-parameter model, where a 1% formal-language (Dyck) warm-up cut tokens-to-threshold on compositional algebra by 12.3% against a scrambled control, in 3 of 3 seeds." },
  { id := "collision", topic := "research",
    keywords := ["collision", "random walks", "lattices", "poissonization", "preprint", "probability", "bessel", "laplace"],
    text := "Zac wrote Poissonization-Based Collision Threshold Derivation for Random Walks on Lattices (arXiv 2505.02973, https://arxiv.org/abs/2505.02973), an expository derivation that uses Poissonization, Laplace asymptotics, and Bessel asymptotics to quantify multi-walk collision behaviour on Z^d lattices." },
  { id := "tabular-rl", topic := "research",
    keywords := ["tabular", "reinforcement learning", "blog", "post", "symbolic algebra", "high school"],
    text := "When Does Tabular RL Actually Break? is a 2025 blog post by Zac (https://zacburton.com/tabular_rl.html) that systematically studies representation bottlenecks in symbolic algebra, testing where tabular reinforcement learning fails on high-school algebra." },
  { id := "research-interests", topic := "research",
    keywords := ["interests", "research interests", "focus", "exploring", "verifier", "autoformalization", "search", "what does zac research"],
    text := "Zac's research interests include verifier-based reinforcement learning, theorem proving, autoformalization, inference-time search, and optimization. Zac's research asks what LLMs can and cannot do in mathematics." },
  { id := "csail", topic := "research",
    keywords := ["csail", "futuretech", "undergraduate research", "urop", "gadgets", "reductions", "pspace", "complexity"],
    text := "From November 2024 to August 2025, Zac was an undergraduate researcher at MIT CSAIL in the FutureTech group, investigating RL-guided search over symbolic gadget construction for PSPACE and NL complexity-theoretic reductions, and building annotation, evaluation, and data pipelines from scratch." },
  { id := "cfar", topic := "research",
    keywords := ["singapore", "cfar", "a*star", "sipga", "continual learning", "chess", "grid worlds", "summer"],
    text := "In summer 2023, after freshman year, Zac received the Singapore International Pre-Graduate Award (SIPGA) to research continual reinforcement learning on grid worlds and chess at the A*STAR Centre for Frontier AI Research (CFAR) in Singapore." },
  { id := "service", topic := "research",
    keywords := ["reviewer", "reviewing", "service", "peer review"],
    text := "Zac is a reviewer for the ICML AI4Math Workshop (2025 and 2026)." },
  { id := "sprintgame", topic := "projects",
    keywords := ["sprintgame", "sprint", "game", "track and field", "athletics", "rpg", "career"],
    text := "The sprintgame (https://sprintgame.net, game title SPRINT) is a browser-based track and field career RPG that Zac built solo. Players go from age 13 to 40 on a calendar based on the real UK athletics season, including English Schools, Loughborough, Bedford, Alexander Stadium, the Diamond League, the World Championships, and the Olympics. Over 200 players have run more than 40,000 races." },
  { id := "sprintgame-engine", topic := "projects",
    keywords := ["engine", "game engine", "simulation", "splits", "bolt", "replay", "3d", "genetic", "training points", "how does"],
    text := "The sprintgame simulates races with 10m splits calibrated against Usain Bolt's 9.58s Berlin splits, and shows each race as a 1x real-time over-the-shoulder 3D replay. Each athlete has 5 hidden genetic dials and a monthly training points budget." },
  { id := "pieface", topic := "projects",
    keywords := ["pieface", "rlhf", "personalization", "ppo", "reward model", "motion planning", "flask"],
    text := "PIEFACE (https://pieface.ai) is a live RLHF platform for interactive policy personalization of an RL agent over motion-planning gadget structures. It uses a Flask and SQLAlchemy backend serving Maskable PPO models over a 217-dim action space, a custom PyTorch reward model trained on per-action accept or reject feedback, and a Cytoscape.js trace visualization frontend." },
  { id := "zos", topic := "projects",
    keywords := ["zos", "rust", "tauri", "desktop", "self-training", "local llm"],
    text := "zOS (https://github.com/zacn04/zOS) is a local LLM self-training desktop loop with step-by-step feedback, written in Rust and Tauri." },
  { id := "fcs", topic := "projects",
    keywords := ["formal complexity science", "fcs", "np-completeness", "karp", "reductions", "sat", "3-coloring", "mathlib", "cslib"],
    text := "Formal Complexity Science is Zac's autoformalization of classical NP-completeness Karp reductions (SAT to 3SAT to 3-COLORING) in Lean 4, built on Mathlib and CSLib." },
  { id := "nanoalphatensor", topic := "projects",
    keywords := ["nanoalphatensor", "alphatensor", "strassen", "matrix multiplication"],
    text := "nanoAlphaTensor is a minimal AlphaTensor reproduction by Zac that rediscovers Strassen's matrix multiplication algorithm in about 30 minutes on a laptop." },
  { id := "overtone", topic := "projects",
    keywords := ["overtone", "singing", "pitch", "harmony", "sight-singing", "music app"],
    text := "Overtone is an interactive web app by Zac for vocal pitch, harmony, and sight-singing training, with a live musical staff and keyboard." },
  { id := "polisci", topic := "projects",
    keywords := ["political", "persuasion", "misinformation", "17.279", "disclosure", "conspiracy", "study"],
    text := "LLM Political Persuasion? (https://zacburton.com/polisci.pdf) is Zac's final paper for MIT 17.279 (Political Misinformation in the Age of Social Media): an independent randomized study (n=174) of how AI disclosure affects belief formation in political conspiracy-framing content." },
  { id := "scribe", topic := "projects",
    keywords := ["scribe", "hackmit", "handwriting", "latex", "hackathon", "autocomplete"],
    text := "Scribe AI (https://devpost.com/software/scribe-slo6iw) is Zac's HackMIT 2023 project: autocomplete from math handwriting to LaTeX." },
  { id := "edu-despite-ai", topic := "projects",
    keywords := ["education despite ai", "ethics", "24.134", "teaching", "syllabus", "instructors", "cheating"],
    text := "Education Despite AI (https://sites.mit.edu/edudespiteai/) is Zac's 24.134 Experiential Ethics final project with Ana Mata-Payerro: a guide for instructors on designing courses and syllabi when students can use AI." },
  { id := "courses-math", topic := "education",
    keywords := ["courses", "classes", "coursework", "math classes", "real analysis", "probability", "algebra", "statistics"],
    text := "Zac's MIT mathematics courses include Real Analysis (18.100P), Seminar in Probability on Random Walks on Graphs (18.604), Modern Algebra (18.703), Probability and Random Variables (18.600), Fundamentals of Statistics (18.650), and Design and Analysis of Algorithms (18.410)." },
  { id := "courses-other", topic := "education",
    keywords := ["courses", "classes", "coursework", "computer science", "machine learning", "acting", "psychology", "game design", "graduate"],
    text := "Zac's other MIT courses include Introduction to Algorithms (6.1210), graduate Reinforcement Learning (6.7920), graduate Program Synthesis (6.5130), Computational Photography (6.8371), Introduction to Machine Learning (6.3900), Political Misinformation (17.279), Introduction to Psychological Science (9.00), Introduction to Acting (21M.600), Acting with the Camera (21T.201), and Game Design Methods (CMS.301). Zac also took Political Psychology (PSY1024) at Harvard." },
  { id := "teaching", topic := "teaching",
    keywords := ["teaching", "taught", "ta", "grader", "mentor", "peru", "misti", "instructor", "lab assistant"],
    text := "Zac taught a 5-day reinforcement learning course in Peru in January 2026 as an instructor for MISTI GTL-AI Peru. At MIT, Zac graded for 18.600 (Probability), mentored students in 18.100 (Real Analysis), was a lab assistant for 6.100, and was an undergraduate TA for 6.0001 with about 200 students." },
  { id := "eloranta", topic := "teaching",
    keywords := ["eloranta", "proposal", "learning platform", "math education", "traffic light", "spaced repetition"],
    text := "Zac proposed a personalised online learning platform for MIT's introductory maths classes for the Eloranta Fellowship, built around traffic-light self-assessment and spaced repetition." },
  { id := "leadership", topic := "activities",
    keywords := ["leadership", "class council", "secretary", "nu delta", "fraternity", "clubs", "activities", "judicial board", "bsu"],
    text := "At MIT, Zac was Secretary of the Class of 2026 Council and helped organize a joint-class trip to Six Flags for about 3,000 students. Zac was also Recruitment Chair and on the Executive Committee at Nu Delta, and served on the Council for Math Majors, the Judicial Board, the BSU Political Action Committee, and as Student Representative on the MIT Math Department Visiting Committee Panel." },
  { id := "honors", topic := "activities",
    keywords := ["honors", "awards", "olympiad", "physics", "nsbe", "prizes"],
    text := "Zac's honors include British Physics Olympiad Gold (2022), a Cambridge Senior Physics Challenge Diamond Award (top 30), NSBE Boston Scholar (2025), and the Singapore International Pre-Graduate Award (2023)." },
  { id := "athletics", topic := "activities",
    keywords := ["track", "athletics", "sprinting", "100m", "60m", "varsity", "soccer", "sports", "running"],
    text := "Zac won bronze in the 60m at the England U17 Indoor Championships (2020), ran varsity track and field at MIT (All-New England in the 100m), and played intramural soccer in the A League." },
  { id := "talks", topic := "activities",
    keywords := ["talks", "speaking", "youtube", "tonbridge", "videos", "lecture"],
    text := "Zac's talks include Being Black at Tonbridge (2021), Why White People Shouldn't Say the N-Word (2022), and a physics microlecture on the magnetic Gauss law, all on YouTube." },
  { id := "music", topic := "interests",
    keywords := ["music", "singing", "choir", "musical theatre", "piano", "dj", "djing", "hamilton", "hadestown", "hobbies"],
    text := "Zac sings, with a choral background and musical theatre including Tick, Tick... Boom!, and would love to play Washington in Hamilton and Hades in Hadestown. Zac also has ABRSM Grade 5 piano and DJs." },
  { id := "interests", topic := "interests",
    keywords := ["interests", "hobbies", "outside work", "fun", "sociology", "politics", "languages", "games"],
    text := "Outside research, Zac is interested in sociology, politics, language learning, building games, and how maths is taught." }
]

/-- Fact groups for broad questions. The exporter checks that every id names a fact. -/
def groups : List Group := [
  { id := "publications",
    triggers := ["published", "publications", "publish", "papers"],
    factIds := ["paper-lean", "qedbench"] },
  { id := "lean-paper",
    triggers := ["lean provers paper", "lean diversity paper", "first-author paper", "first author paper"],
    factIds := ["paper-lean", "paper-lean-results"] },
  { id := "qedbench",
    triggers := ["qedbench"],
    factIds := ["qedbench", "qedbench-role"] },
  { id := "transfer",
    triggers := ["transfer study", "negative transfer", "visual reasoning", "dyck"],
    factIds := ["neg-transfer", "dyck"] },
  { id := "career",
    triggers := ["where has zac worked", "worked at", "work history", "career", "jobs", "employment", "employers"],
    factIds := ["pramaana", "meta-mle", "meta-intern"] },
  { id := "meta",
    triggers := ["meta"],
    factIds := ["meta-mle", "meta-intern"] },
  { id := "education",
    triggers := ["zac's education", "schooling", "where did zac study", "where did zac go to school", "studied"],
    factIds := ["mit", "tonbridge"] },
  { id := "lean",
    triggers := ["lean", "formal methods", "theorem proving", "formal verification"],
    factIds := ["pramaana", "paper-lean", "fcs"] },
  { id := "rl",
    triggers := ["reinforcement learning research", "rl work", "rl research"],
    factIds := ["paper-lean", "csail", "cfar"] },
  { id := "undergrad-research",
    triggers := ["undergraduate research", "research experience", "as an undergraduate"],
    factIds := ["csail", "cfar"] },
  { id := "sprintgame",
    triggers := ["sprintgame", "sprint"],
    factIds := ["sprintgame", "sprintgame-engine"] },
  { id := "projects",
    triggers := ["projects", "what has zac built", "what has zac made"],
    factIds := ["sprintgame", "pieface", "zos"] },
  { id := "ml-projects",
    triggers := ["ml projects", "language models", "llm projects"],
    factIds := ["pieface", "zos", "nanoalphatensor"] },
  { id := "courses",
    triggers := ["courses", "coursework", "classes"],
    factIds := ["courses-math", "courses-other"] },
  { id := "teaching",
    triggers := ["teaching", "taught", "teach", "education work", "involved in education"],
    factIds := ["teaching", "eloranta", "edu-despite-ai"] },
  { id := "outside-work",
    triggers := ["outside of research", "outside research", "outside work", "hobbies", "for fun", "free time"],
    factIds := ["music", "interests", "athletics"] },
  { id := "awards",
    triggers := ["awards", "honors", "honours", "achievements"],
    factIds := ["honors", "athletics"] },
  { id := "ai-society",
    triggers := ["ai and society", "ethics", "misinformation"],
    factIds := ["polisci", "edu-despite-ai"] },
  { id := "math-research",
    triggers := ["math research", "maths research", "mathematical research", "pure math"],
    factIds := ["collision", "qedbench-role"] },
  { id := "current-focus",
    triggers := ["researching now", "current research", "research focus", "research interests"],
    factIds := ["pramaana", "research-interests"] }
]

/-- Instructions shown to the model. `{facts}` is replaced with the retrieved facts. -/
def systemPrompt : String :=
  "You are Ask Zac AI, a small assistant on zacburton.com that answers questions about Zac Burton. Answer in one to three plain sentences, using only the facts below. If the facts do not answer the question, say that you do not have verified information about that, and suggest emailing zacnburton@gmail.com. Never share private details.\n\nFacts:\n{facts}"

/-- Lowercase terms that must never appear in a fact. Private terms go in an untracked
`_zac_lm/private_blocklist.txt`, read by the exporter, so they are never published. -/
def publicBlocklist : List String :=
  ["bellman", "baller", "bay area", "fiance", "roommate", "student loan", "medical", "adhd", "salary", "imessage"]

/-! ## Bindings: each number or date that a theorem talks about must appear, as written,
in the text of the named fact. The exporter enforces this. -/

def roleBindings : List Role → List (String × String)
  | [] => []
  | r :: rs =>
    (r.factId, r.start.render) ::
      ((if r.current then [] else [(r.factId, r.stop.render)]) ++ roleBindings rs)

def bindings : List (String × String) :=
  roleBindings roles ++ [
    ("neg-transfer", s!"All {negTransfer.conditions} "),
    ("neg-transfer", s!"{tenths negTransfer.base}%"),
    ("neg-transfer", s!"{tenths negTransfer.lo}%"),
    ("neg-transfer", s!"{tenths negTransfer.hi}%"),
    ("paper-lean-results", s!"k={proverStudy.kBefore}"),
    ("paper-lean-results", s!"k={proverStudy.kAfter}"),
    ("paper-lean-results", s!"solves {proverStudy.extraSolved} additional"),
    ("paper-lean-results", s!"{proverStudy.skeletons} tactic skeletons"),
    ("paper-lean-results", s!"{tenths proverStudy.gain} +/- {tenths proverStudy.sd}"),
    ("paper-lean-results", s!"{proverStudy.seeds} seeds"),
    ("dyck", s!"{dyck.paramsM}M"),
    ("dyck", s!"{dyck.warmupPct}%"),
    ("dyck", s!"{tenths dyck.cut}%"),
    ("dyck", s!"{dyck.seedsBetter} of {dyck.seeds} seeds"),
    ("mit", s!"{tenths gpa}/5.0")
  ]

end ZacFacts
