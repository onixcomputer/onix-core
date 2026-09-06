# r[verify onix.hermes_desktop.validation.positive]
# r[verify onix.hermes_desktop.validation.negative]
let sc = import "../settings-contracts.ncl" in
let default_packages = ["pi", "openspec", "hermes-agent"] in
{
  role_positive =
    sc.validate_fields
      "llm-agents:default"
      "llm-agents-role-positive"
      {
        # Role-level default package set plus the aspen3 machine delta.
        packages = std.array.concat default_packages ["hermes-desktop"],
      },
  role_negative =
    sc.validate_fields
      "llm-agents:default"
      "llm-agents-role-negative"
      {
        packages = "hermes-desktop",
      },
}
