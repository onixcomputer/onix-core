let Contracts = import "../../contracts.ncl" in
(Contracts.expected & { threshold | force = 0 })
  | Contracts.PolicyShape
  | Contracts.GuardPolicy
