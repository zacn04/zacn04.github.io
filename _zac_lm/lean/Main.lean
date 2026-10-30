import ZacFacts.Checks

/-
Exporter: `lake exe zackb <out.json>`.

Importing `ZacFacts.Checks` means this program only builds if every theorem holds.
At run time it also checks the text rules below, and writes nothing if any fails.
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
  let texts := systemPrompt :: facts.map (·.text)
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
  for (fid, s) in bindings do
    match facts.find? (·.id == fid) with
    | none => out := out ++ [s!"binding refers to unknown fact {fid}"]
    | some f =>
      if !(containsStr f.text s) then
        out := out ++ [s!"fact {fid} must contain the checked value \"{s}\""]
  return out

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

def main (args : List String) : IO UInt32 := do
  let outPath := args.headD "zac_kb.json"
  let privPath : System.FilePath := "../private_blocklist.txt"
  let mut priv : List String := []
  if (← privPath.pathExists) then
    let txt ← IO.FS.readFile privPath
    priv := ((txt.splitOn "\n").map String.trim).filter (· != "")
  let errs := problems (publicBlocklist ++ priv)
  if !errs.isEmpty then
    for e in errs do
      IO.eprintln e
    IO.eprintln s!"{errs.length} problem(s); zac_kb.json was not written."
    return 1
  let body := ",\n".intercalate (facts.map factJson)
  let json :=
    "{\n" ++
    "\"verifier\": \"lean\",\n" ++
    s!"\"as_of\": {jStr asOf.render},\n" ++
    s!"\"theorems\": {jArr (theoremNames.map jStr)},\n" ++
    s!"\"blocklist\": {jArr (publicBlocklist.map jStr)},\n" ++
    s!"\"system_prompt\": {jStr systemPrompt},\n" ++
    s!"\"facts\": [\n{body}\n]\n" ++
    "}\n"
  IO.FS.writeFile outPath json
  IO.println s!"Checked {theoremNames.length} theorems and {bindings.length} bindings; wrote {facts.length} facts to {outPath}"
  return 0
