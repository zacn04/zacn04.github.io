import ZacFacts.Data

/-
Rules the fact sheet must satisfy. Each one is checked by the Lean kernel with `decide`,
so `lake build` fails if an edit to `Data.lean` breaks it.
-/
namespace ZacFacts

/-- Every month in Zac's dated roles is a real calendar month. -/
theorem months_valid :
    (roles.all fun r =>
      decide (1 ≤ r.start.month ∧ r.start.month ≤ 12 ∧ 1 ≤ r.stop.month ∧ r.stop.month ≤ 12)) = true := by
  decide

/-- Every one of Zac's roles ends on or after the month it starts. -/
theorem roles_ordered : (roles.all fun r => decide (r.start.idx ≤ r.stop.idx)) = true := by
  decide

/-- No role starts after the date the fact sheet describes. -/
theorem roles_not_in_future : (roles.all fun r => decide (r.start.idx ≤ asOf.idx)) = true := by
  decide

/-- Zac's Meta internship happened while Zac was a student at MIT. -/
theorem intern_during_mit :
    mit.start.idx ≤ metaIntern.start.idx ∧ metaIntern.stop.idx ≤ mit.stop.idx := by
  decide

/-- Zac's CSAIL research happened while Zac was a student at MIT. -/
theorem csail_during_mit : mit.start.idx ≤ csail.start.idx ∧ csail.stop.idx ≤ mit.stop.idx := by
  decide

/-- Zac graduated from MIT before starting full-time at Meta. -/
theorem graduated_before_meta : mit.stop.idx ≤ metaMLE.start.idx := by
  decide

/-- Zac left Meta before joining Pramaana Labs. -/
theorem meta_before_pramaana : metaMLE.stop.idx < pramaana.start.idx := by
  decide

/-- Pramaana Labs is Zac's only current role. -/
theorem only_pramaana_current :
    (roles.filter (·.current)).length = 1 ∧ pramaana.current = true := by
  decide

/-- In the transfer study, even the best trained model scored below the base model, so every condition showed negative transfer. -/
theorem neg_transfer_all_negative :
    negTransfer.lo ≤ negTransfer.hi ∧ negTransfer.hi < negTransfer.base := by
  decide

/-- In the Lean provers paper, going from k=32 to k=64 doubles the sampling budget. -/
theorem prover_budget_doubled : proverStudy.kAfter = 2 * proverStudy.kBefore := by
  decide

/-- In the Lean provers paper, the doubled sampling budget solved 0 additional theorems. -/
theorem prover_plateau : proverStudy.extraSolved = 0 := by
  decide

/-- In the Lean provers paper, the mean gain from tactic skeletons is larger than its standard deviation. -/
theorem prover_gain_exceeds_sd : proverStudy.sd < proverStudy.gain := by
  decide

/-- In the Dyck pretraining experiment, every seed improved. -/
theorem dyck_all_seeds : dyck.seedsBetter = dyck.seeds ∧ 0 < dyck.seeds := by
  decide

/-- Zac's GPA is within the 5.0 scale. -/
theorem gpa_in_range : gpa ≤ 50 := by
  decide

/-- Names of the theorems above, exported so the website can list them. -/
def theoremNames : List String :=
  ["months_valid", "roles_ordered", "roles_not_in_future", "intern_during_mit",
   "csail_during_mit", "graduated_before_meta", "meta_before_pramaana", "only_pramaana_current",
   "neg_transfer_all_negative", "prover_budget_doubled", "prover_plateau",
   "prover_gain_exceeds_sd", "dyck_all_seeds", "gpa_in_range"]

end ZacFacts
