import ZacFacts.Checks

/-
Exporter: `lake build && lake env lean --run Main.lean <out.json>`.

Importing `ZacFacts.Checks` means this program only builds if every theorem holds.
At run time it also checks the text rules below, and writes nothing if any fails.
Run it from the `lean` folder: it reads `ZacFacts/Checks.lean` to export each theorem's
source, so the website shows exactly what the kernel checked.
-/
open ZacFacts

def isInfix (t s : List Char) : Bool :=
  match s with
  | [] => t.isEmpty
  | c :: cs => t.isPrefixOf (c :: cs) || isInfix t cs

def containsStr (s t : String) : Bool := isInfix t.toList s.toList

def lower (s : String) : String := s.map Char.toLower

def emDash : Char := Char.ofNat 0x2014

/-- Every text-level problem with the fact sheet, given the full blocklist. -/
def problems (block : List String) : List String := Id.run do
  let mut out : List String := []
  let ids := facts.map (·.id)
  let texts := systemPrompt :: (facts.map (·.text) ++ templates.map (·.2))
  for f in facts do
    if (ids.filter (· == f.id)).length != 1 then
      out := out ++ [s!"duplicate fact id: {f.id}"]
    if f.text.isEmpty || f.keywords.isEmpty then
      out := out ++ [s!"fact {f.id} needs text and keywords"]
  for t in texts do
    if t.toList.contains emDash then
      out := out ++ [s!"em dash in: {t.take 60}"]
    for b in block do
      if containsStr (lower t) (lower b) then
        out := out ++ [s!"blocked term found in: {t.take 60}"]
  for g in groups do
    if (groups.filter (·.id == g.id)).length != 1 then
      out := out ++ [s!"duplicate group id: {g.id}"]
    if g.triggers.isEmpty || g.factIds.isEmpty then
      out := out ++ [s!"group {g.id} needs triggers and facts"]
    for t in g.triggers do
      if t != lower t then
        out := out ++ [s!"group {g.id} trigger must be lowercase: {t}"]
    for i in g.factIds do
      if !(ids.contains i) then
        out := out ++ [s!"group {g.id} refers to unknown fact {i}"]
  for (fid, s) in bindings do
    match facts.find? (·.id == fid) with
    | none => out := out ++ [s!"binding refers to unknown fact {fid}"]
    | some f =>
      if !(containsStr f.text s) then
        out := out ++ [s!"fact {fid} must contain the checked value \"{s}\""]
  return out

/-- Split source text into blocks of consecutive non-blank lines. -/
def blocks (txt : String) : List (List String) := Id.run do
  let mut out : List (List String) := []
  let mut cur : List String := []
  for line in txt.splitOn "\n" do
    if line.trim.isEmpty then
      if !cur.isEmpty then
        out := out ++ [cur]
        cur := []
    else
      cur := cur ++ [line]
  if !cur.isEmpty then
    out := out ++ [cur]
  return out

structure ProofSrc where
  name : String
  doc : String
  source : String

/-- Each theorem in `Checks.lean`, with its doc comment and its exact source. -/
def proofSources (txt : String) : List ProofSrc :=
  (blocks txt).filterMap fun ls =>
    match ls.find? (·.startsWith "theorem ") with
    | none => none
    | some t =>
      let name := (t.drop 8).takeWhile (fun c => c != ' ' && c != ':')
      let docLines := ls.takeWhile (fun l => !l.startsWith "theorem ")
      let doc := (((" ".intercalate (docLines.map String.trim)).replace "/--" "").replace "-/" "").trim
      some { name := name, doc := doc, source := "\n".intercalate ls }

def jsonEscape (s : String) : String :=
  s.foldl (fun acc c =>
    if c == '"' then acc ++ "\\\""
    else if c == '\\' then acc ++ "\\\\"
    else if c == '\n' then acc ++ "\\n"
    else if c.toNat < 0x20 then acc ++ " "
    else acc.push c) ""

def jStr (s : String) : String := "\"" ++ jsonEscape s ++ "\""

def jArr (xs : List String) : String := "[" ++ ", ".intercalate xs ++ "]"

def factJson (f : Fact) : String :=
  "{" ++ ", ".intercalate [
    s!"\"id\": {jStr f.id}",
    s!"\"topic\": {jStr f.topic}",
    s!"\"keywords\": {jArr (f.keywords.map jStr)}",
    s!"\"text\": {jStr f.text}"] ++ "}"

def groupJson (g : Group) : String :=
  "{" ++ ", ".intercalate [
    s!"\"id\": {jStr g.id}",
    s!"\"triggers\": {jArr (g.triggers.map jStr)}",
    s!"\"facts\": {jArr (g.factIds.map jStr)}"] ++ "}"

def proofJson (p : ProofSrc) : String :=
  "{" ++ ", ".intercalate [
    s!"\"name\": {jStr p.name}",
    s!"\"doc\": {jStr p.doc}",
    s!"\"source\": {jStr p.source}"] ++ "}"

def templatesJson : String :=
  "{" ++ ", ".intercalate (templates.map fun (k, v) => s!"{jStr k}: {jStr v}") ++ "}"

def main (args : List String) : IO UInt32 := do
  let outPath := args.headD "zac_kb.json"
  let privPath : System.FilePath := "../private_blocklist.txt"
  let mut priv : List String := []
  if (← privPath.pathExists) then
    let txt ← IO.FS.readFile privPath
    priv := ((txt.splitOn "\n").map String.trim).filter (· != "")
  let proofs := proofSources (← IO.FS.readFile "ZacFacts/Checks.lean")
  let mut errs := problems (publicBlocklist ++ priv)
  for n in theoremNames do
    if !(proofs.any (·.name == n)) then
      errs := errs ++ [s!"no source found for theorem {n}"]
  for p in proofs do
    if !(theoremNames.contains p.name) then
      errs := errs ++ [s!"theorem {p.name} is missing from theoremNames"]
    if p.doc.isEmpty then
      errs := errs ++ [s!"theorem {p.name} needs a doc comment"]
    if p.doc.toList.contains emDash then
      errs := errs ++ [s!"em dash in the doc comment of {p.name}"]
  if !errs.isEmpty then
    for e in errs do
      IO.eprintln e
    IO.eprintln s!"{errs.length} problem(s); zac_kb.json was not written."
    return 1
  let body := ",\n".intercalate (facts.map factJson)
  let groupsBody := ",\n".intercalate (groups.map groupJson)
  let proofsBody := ",\n".intercalate (proofs.map proofJson)
  let json :=
    "{\n" ++
    "\"verifier\": \"lean\",\n" ++
    s!"\"as_of\": {jStr asOf.render},\n" ++
    s!"\"theorems\": {jArr (theoremNames.map jStr)},\n" ++
    s!"\"blocklist\": {jArr (publicBlocklist.map jStr)},\n" ++
    s!"\"system_prompt\": {jStr systemPrompt},\n" ++
    s!"\"templates\": {templatesJson},\n" ++
    s!"\"proofs\": [\n{proofsBody}\n],\n" ++
    s!"\"groups\": [\n{groupsBody}\n],\n" ++
    s!"\"facts\": [\n{body}\n]\n" ++
    "}\n"
  IO.FS.writeFile outPath json
  IO.println s!"Checked {theoremNames.length} theorems and {bindings.length} bindings; wrote {facts.length} facts, {groups.length} groups, and {proofs.length} proofs to {outPath}"
  return 0
