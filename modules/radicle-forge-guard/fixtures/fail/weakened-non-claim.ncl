let Contracts = import "../../contracts.ncl" in
(
  Contracts.expected
  & {
    required_non_claims
      | force
      = ["guard proves mandatory CI and release readiness"],
  }
)
  | Contracts.PolicyShape
  | Contracts.GuardPolicy
