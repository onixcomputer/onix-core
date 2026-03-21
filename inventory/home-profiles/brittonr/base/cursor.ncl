# Cursor theme settings — source of truth.
#
# Theme name and size. The Nix package reference stays in cursor.nix
# since Nickel can't resolve Nix packages.
#
# Consumed by: cursor.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/cursor.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let CursorSize =
  let valid = [16, 24, 32, 48, 64] in
  std.contract.from_validator (match {
    value if std.is_number value && std.array.elem value valid => 'Ok,
    _ =>
      'Error {
        message = "must be a standard cursor size",
        notes = ["Valid sizes: %{std.serialize 'Json valid}"],
      },
  }
  )
in

{
  name | doc "Cursor theme name (must match package)" | NonEmpty = "phinger-cursors-dark",
  size | doc "Cursor size in pixels" | CursorSize = 24,
}
