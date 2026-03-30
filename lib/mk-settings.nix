# Generate NixOS interface options and extendSettings defaults from
# an evaluated module schema (produced by wasm.evalNickelFile).
#
# Usage:
#   let mkSettings = import "${self}/lib/mk-settings.nix" { inherit lib; };
#   mkSettings.mkInterface schema.roles.default
#   mkSettings.mkDefaults  schema.roles.default
#
{ lib }:
let
  inherit (lib) mkOption mkDefault;

  # Map schema type tags to NixOS option types.
  typeMap = {
    "bool" = lib.types.bool;
    "string" = lib.types.str;
    "number" = lib.types.int;
    "port" = lib.types.port;
    "array" = lib.types.listOf lib.types.anything;
    "array_string" = lib.types.listOf lib.types.str;
    "record" = lib.types.attrsOf lib.types.anything;
    "nullable_string" = lib.types.nullOr lib.types.str;
    "nullable_record" = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
    # "enum" handled separately — needs the values list
  };

  # Build a single mkOption from a field descriptor.
  mkOpt =
    name: fd:
    let
      nixType =
        if fd.type == "enum" then
          lib.types.enum fd.values
        else
          typeMap.${fd.type} or (throw "mk-settings: unknown type '${fd.type}' for field '${name}'");

      base = {
        type = nixType;
      }
      // lib.optionalAttrs (fd ? description) { inherit (fd) description; };
    in
    mkOption (base // lib.optionalAttrs (fd ? default) { inherit (fd) default; });
in
{
  # Generate a clan service role interface from an evaluated schema role.
  #
  # Input:  { field_name = { type, default?, description?, values? }; ... }
  # Output: { freeformType = attrsOf anything; options = { field = mkOption ...; ... }; }
  mkInterface = roleSchema: {
    freeformType = lib.types.attrsOf lib.types.anything;
    options = builtins.mapAttrs mkOpt roleSchema;
  };

  # Generate an extendSettings default attrset from an evaluated schema role.
  # Only fields with a `default` are included. Each is wrapped in mkDefault.
  #
  # Input:  { field_name = { type, default?, ... }; ... }
  # Output: { field_name = mkDefault value; ... }
  mkDefaults =
    roleSchema:
    lib.mapAttrs (_: fd: mkDefault fd.default) (lib.filterAttrs (_: fd: fd ? default) roleSchema);
}
