# Editor settings — source of truth.
#
# Defines text width, rulers, soft wrap, auto-save, and diagnostics
# settings for text editors.
#
# Consumed by: editor.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/editor.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

{
  textWidth | doc "Text width in characters" | Positive = 80,
  rulers | doc "Column ruler positions" | Array Positive = [80],
  softWrap | doc "Soft wrap settings" = {
    maxWrap | doc "Maximum wrap length" | Positive = 25,
    maxWrapZen | doc "Maximum wrap length in zen mode" | Positive = 40,
  },
  autoSave | doc "Auto-save settings" = {
    timeout | doc "Auto-save timeout in milliseconds" | Positive = 3000,
  },
  inlineDiagnostics | doc "Inline diagnostics settings" = {
    maxCount | doc "Maximum diagnostic count to show" | Positive = 5,
    prefixLen | doc "Diagnostic prefix length" | Positive = 2,
  },
}
