# CSS sizing and timing values — source of truth.
#
# Defines shared CSS values for waybar and other GTK widgets.
# All strings represent CSS property values.
#
# Consumed by: css.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/css.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

{
  borderRadius | doc "CSS border-radius values" = {
    sm | NonEmpty = "0.5em",
    md | NonEmpty = "0.6em",
    lg | NonEmpty = "0.7em",
    px8 | NonEmpty = "8px",
    px12 | NonEmpty = "12px",
  },

  padding | doc "CSS padding values" = {
    xs | NonEmpty = "0.2em",
    sm | NonEmpty = "0.3em",
    normal | NonEmpty = "0.4em",
    md | NonEmpty = "0.5em",
    lg | NonEmpty = "0.6em",
    xl | NonEmpty = "0.8em",
  },

  fontSize | doc "CSS font-size values in pixels" = {
    sm | NonEmpty = "13px",
    md | NonEmpty = "14px",
    lg | NonEmpty = "16px",
  },

  transition | doc "CSS transition values" = {
    fast | NonEmpty = "0.2s",
    normal | NonEmpty = "0.4s",
    drawerMs | NonEmpty = "450ms",
    easing | NonEmpty = "cubic-bezier(0.4, 0, 0.2, 1)",
  },

  spacing | doc "CSS spacing values in pixels" = {
    px2 | NonEmpty = "2px",
    px5 | NonEmpty = "5px",
    px10 | NonEmpty = "10px",
    px15 | NonEmpty = "15px",
  },

  borderWidth | doc "CSS border-width values" = {
    thin | NonEmpty = "1px",
    normal | NonEmpty = "2px",
    thick | NonEmpty = "3px",
  },

  fontSizeEm | doc "CSS font-size values in em units" = {
    small | NonEmpty = "0.9em",
    normal | NonEmpty = "1em",
    large | NonEmpty = "1.2em",
    xlarge | NonEmpty = "1.6em",
  },

  marginEm | doc "CSS margin values in em units" = {
    tiny | NonEmpty = "0.1em",
    sm | NonEmpty = "0.3em",
    md | NonEmpty = "0.5em",
  },

  paddingEm | doc "CSS padding values in em units" = {
    sm | NonEmpty = "0.4em",
  },
}
