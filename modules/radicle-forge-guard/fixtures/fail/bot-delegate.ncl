let Contracts = import "../../contracts.ncl" in
(
  Contracts.expected
  & {
    delegates
      | force
      = [Contracts.expected.bot_did],
  }
)
  | Contracts.PolicyShape
  | Contracts.GuardPolicy
