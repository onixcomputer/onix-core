{ lib, pkgs }:
let
  emailTemplateDirectory = ./email-templates;
  manifest = builtins.fromJSON (builtins.readFile (emailTemplateDirectory + "/manifest.json"));
  templateNames = map (file: file.name) manifest.files;
  uniqueTemplateNames = lib.unique templateNames;
  hashes = lib.concatMapStringsSep "\n" (file: "${file.blake3}  ${file.name}") manifest.files;
  copiedTemplates = lib.concatMapStringsSep "\n" (name: ''
    install -m 0444 "${emailTemplateDirectory}/${name}" "$emailDirectory/${name}"
  '') templateNames;
  manifestIsValid =
    manifest.schema_version == 1
    && manifest.upstream.project == "Grafana"
    && manifest.upstream.version == pkgs.grafana.version
    && builtins.length templateNames == builtins.length uniqueTemplateNames
    && builtins.all (file: builtins.match "[0-9a-f]{64}" file.blake3 != null) manifest.files;
in
assert lib.assertMsg manifestIsValid
  "Grafana email-template manifest is malformed, duplicated, or version-mismatched";
pkgs.runCommand "${pkgs.grafana.name}-with-email-templates"
  {
    nativeBuildInputs = [ pkgs.b3sum ];
    inherit (pkgs.grafana) meta;
    passthru = (pkgs.grafana.passthru or { }) // {
      emailTemplateManifest = manifest;
    };
  }
  ''
    expectedHashes="$TMPDIR/expected-email-template-hashes"
    cat > "$expectedHashes" <<'EOF'
    ${hashes}
    EOF

    (
      cd ${emailTemplateDirectory}
      b3sum --check "$expectedHashes"
    )

    cp -a ${pkgs.grafana}/. "$out/"
    emailDirectory="$out/share/grafana/public/emails"
    chmod -R u+w "$out/share/grafana/public"
    rm -rf "$emailDirectory"
    install -d -m 0755 "$emailDirectory"
    ${copiedTemplates}
    chmod 0555 "$emailDirectory"
  ''
