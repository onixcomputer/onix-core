# r[verify onix.hermes_agent.validation.inventory]
# r[verify onix.hermes_agent.validation.negative]
let sc = import "../settings-contracts.ncl" in
let default_packages = ["pi", "openspec"] in
{
  role_positive =
    sc.validate_fields
      "llm-agents:default"
      "llm-agents-role-positive"
      {
        # Shared CLI set; aspen3 picks up the official Hermes via home-manager.
        packages = default_packages,
      },
  role_negative =
    sc.validate_fields
      "llm-agents:default"
      "llm-agents-role-negative"
      {
        packages = "hermes-agent",
      },
}
