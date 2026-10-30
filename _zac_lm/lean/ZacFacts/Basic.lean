/-
Types for the Ask Zac AI fact sheet.

Dates are calendar months. Decimals are stored as tenths (668 means 66.8) so every
numeric rule can be checked by the kernel with `decide`.
-/
namespace ZacFacts

structure YM where
  year : Nat
  month : Nat
  deriving Repr

/-- Months since year 0, used to compare dates. -/
def YM.idx (d : YM) : Nat := d.year * 12 + d.month

def monthName : Nat → String
  | 1 => "January"
  | 2 => "February"
  | 3 => "March"
  | 4 => "April"
  | 5 => "May"
  | 6 => "June"
  | 7 => "July"
  | 8 => "August"
  | 9 => "September"
  | 10 => "October"
  | 11 => "November"
  | 12 => "December"
  | _ => "?"

def YM.render (d : YM) : String := s!"{monthName d.month} {d.year}"

/-- A dated role. `factId` names the fact whose text must state these dates. -/
structure Role where
  factId : String
  start : YM
  stop : YM
  current : Bool := false

structure Fact where
  id : String
  topic : String
  keywords : List String
  text : String

/-- A broad question that needs several facts at once, such as "Where has Zac worked?".
If a visitor's question contains one of `triggers` (lowercase phrases), retrieval puts
these facts first, in this order. -/
structure Group where
  id : String
  triggers : List String
  factIds : List String

/-- Render a tenths value, e.g. `tenths 668 = "66.8"`. -/
def tenths (n : Nat) : String := s!"{n / 10}.{n % 10}"

end ZacFacts
