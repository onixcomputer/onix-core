let sc = import "../settings-contracts.ncl" in
let default_packages = ["pi", "openspec", "hermes-agent"] in
{
  role_positive =
    sc.validate_fields
      "llm-agents:default"
      "llm-agents-role-positive"
      {
        # The shared llm-client CLI set from inventory/services/services.ncl.
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
