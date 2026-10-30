import ZacFacts.Data

/-
Rules the fact sheet must satisfy. Each one is checked by the Lean kernel with `decide`,
so `lake build` fails if an edit to `Data.lean` breaks it.
-/
namespace ZacFacts

/-- Every month is a real month. -/
theorem months_valid :
    (roles.all fun r =>
      decide (1 ≤ r.start.month ∧ r.start.month ≤ 12 ∧ 1 ≤ r.stop.month ∧ r.stop.month ≤ 12)) = true := by
  decide

/-- Every role ends on or after it starts. -/
theorem roles_ordered : (roles.all fun r => decide (r.start.idx ≤ r.stop.idx)) = true := by
  decide

/-- No role starts after the date the fact sheet describes. -/
theorem roles_not_in_future : (roles.all fun r => decide (r.start.idx ≤ asOf.idx)) = true := by
  decide

/-- The Meta internship and the CSAIL research happened while Zac was at MIT. -/
theorem intern_during_mit :
    mit.start.idx ≤ metaIntern.start.idx ∧ metaIntern.stop.idx ≤ mit.stop.idx := by
  decide

theorem csail_during_mit : mit.start.idx ≤ csail.start.idx ∧ csail.stop.idx ≤ mit.stop.idx := by
  decide

/-- Zac graduated before starting full-time at Meta, and left Meta before joining Pramaana. -/
theorem graduated_before_meta : mit.stop.idx ≤ metaMLE.start.idx := by
  decide

theorem meta_before_pramaana : metaMLE.stop.idx < pramaana.start.idx := by
  decide

/-- Pramaana is the only current role. -/
theorem only_pramaana_current :
    (roles.filter (·.current)).length = 1 ∧ pramaana.current = true := by
  decide

/-- "All conditions showed negative transfer": the best trained score is below the base. -/
theorem neg_transfer_all_negative :
    negTransfer.lo ≤ negTransfer.hi ∧ negTransfer.hi < negTransfer.base := by
  decide

/-- "Doubling the sampling budget": k went from 32 to 64. -/
theorem prover_budget_doubled : proverStudy.kAfter = 2 * proverStudy.kBefore := by
  decide

/-- "Solves 0 additional theorems" at the doubled budget. -/
theorem prover_plateau : proverStudy.extraSolved = 0 := by
  decide

/-- "Breaks the plateau": the mean gain exceeds one standard deviation. -/
theorem prover_gain_exceeds_sd : proverStudy.sd < proverStudy.gain := by
  decide

/-- "In 3 of 3 seeds": every seed improved. -/
theorem dyck_all_seeds : dyck.seedsBetter = dyck.seeds ∧ 0 < dyck.seeds := by
  decide

/-- The GPA is on a 5.0 scale. -/
theorem gpa_in_range : gpa ≤ 50 := by
  decide

/-- Names of the theorems above, exported so the website can list them. -/
def theoremNames : List String :=
  ["months_valid", "roles_ordered", "roles_not_in_future", "intern_during_mit",
   "csail_during_mit", "graduated_before_meta", "meta_before_pramaana", "only_pramaana_current",
   "neg_transfer_all_negative", "prover_budget_doubled", "prover_plateau",
   "prover_gain_exceeds_sd", "dyck_all_seeds", "gpa_in_range"]

end ZacFacts
