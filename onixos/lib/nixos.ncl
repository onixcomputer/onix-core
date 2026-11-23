# NixOS module-system wrappers expressible as plain Nickel data.
#
# lib.mkOverride/mkOrder build attribute sets that the NixOS module system
# recognises by `_type`; output.nixos values pass through unchanged, so a
# service can set option priority and list order exactly like the Clan
# module it replaces. Conditions on `config` (lib.mkIf) are not expressible.
let mk_override = fun prio value => { _type = "override", priority = prio, content = value } in
let mk_order = fun prio value => { _type = "order", priority = prio, content = value } in
{
  mk_force = mk_override 50,
  mk_default = mk_override 1000,
  mk_option_default = mk_override 1500,
  mk_before = mk_order 500,
  mk_after = mk_order 1500,
}
