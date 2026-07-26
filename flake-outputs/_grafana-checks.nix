{ lib, pkgs, ... }:
let
  emailTemplateDirectory = ../modules/grafana/email-templates;
  manifest = builtins.fromJSON (builtins.readFile (emailTemplateDirectory + "/manifest.json"));
  expectedTemplateCount = builtins.length manifest.files;
  firstTemplateName = (builtins.head manifest.files).name;
  expectedHashes = lib.concatMapStringsSep "\n" (file: "${file.blake3}  ${file.name}") manifest.files;
  grafanaWithEmailTemplates = import ../modules/grafana/package.nix { inherit lib pkgs; };
in
{
  checks.grafana-email-templates =
    pkgs.runCommand "grafana-email-templates-check"
      {
        nativeBuildInputs = [
          pkgs.b3sum
          pkgs.coreutils
          pkgs.findutils
        ];
      }
      ''
        expectedHashes="$TMPDIR/expected-email-template-hashes"
        cat > "$expectedHashes" <<'EOF'
        ${expectedHashes}
        EOF

        packageEmailDirectory=${grafanaWithEmailTemplates}/share/grafana/public/emails
        actualTemplateCount=$(find "$packageEmailDirectory" -maxdepth 1 -type f | wc -l)
        test "$actualTemplateCount" -eq ${toString expectedTemplateCount}
        (
          cd "$packageEmailDirectory"
          b3sum --check "$expectedHashes"
        )

        invalidDirectory="$TMPDIR/invalid-email-templates"
        cp -a ${emailTemplateDirectory} "$invalidDirectory"
        chmod -R u+w "$invalidDirectory"
        printf '\ninvalid fixture\n' >> "$invalidDirectory/${firstTemplateName}"
        if (
          cd "$invalidDirectory"
          b3sum --check "$expectedHashes" >/dev/null 2>&1
        ); then
          echo "tampered Grafana email template unexpectedly passed validation" >&2
          exit 1
        fi

        touch "$out"
      '';
}
