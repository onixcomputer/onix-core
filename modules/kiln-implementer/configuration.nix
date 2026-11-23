# Export actual owner-typed inputs; no credential enters this bundle.
{ pkgs, lib }:
{ enrollment, githubPolicy, cairnPolicy, workerTransportProfile, workClass, repository
, selectedCampaign ? null, selectedCampaignCohort ? null, campaignDataGid ? null
, selectedCampaignCredentialPath ? null
, coordinatorUid ? 930, executorUid ? 931, publisherUid ? 932, verifierUid ? 933
, runtimeName ? "kiln-implementation" }:
assert lib.assertMsg (builtins.elem workClass [ "bug" "bounded-feature" ]) "Select an explicit first-pilot work class";
assert lib.assertMsg ((selectedCampaign == null) == (selectedCampaignCohort == null)) "Selected campaign inputs require their separately capability-admitted cohort";
assert lib.assertMsg (selectedCampaign == null || campaignDataGid != null) "Selected campaign profile requires its explicitly configured data group";
pkgs.runCommand "kiln-implementation-configuration" {
  nativeBuildInputs = [ pkgs.nickel pkgs.b3sum pkgs.jq pkgs.util-linux ];
  passthru.selectedCampaign = selectedCampaign != null;
} ''
  mkdir -p "$out"
  nickel export --format json ${enrollment} > "$out/enrollment.json"
  nickel export --format json ${githubPolicy} > "$out/github-policy.json"
  nickel export --format json ${cairnPolicy} > "$out/cairn-policy.json"
  nickel export --format json ${workerTransportProfile} > "$out/worker-transport-profile.json"
  jq -n --arg class ${lib.escapeShellArg workClass} --arg repository ${lib.escapeShellArg repository} \
    --arg policy_blake3 "$(b3sum --no-names "$out/github-policy.json")" \
    '{class:$class,repository:$repository,policy_blake3:$policy_blake3}' > "$out/work-class.json"
  ${lib.optionalString (selectedCampaign != null) ''
    cohort_manifest=${selectedCampaignCohort}/manifest.json
    lattice_program="$(jq -er '.entries.lattice.resolved_path' "$cohort_manifest")"
    lattice_blake3="$(jq -er '.entries.lattice.blake3' "$cohort_manifest")"
    jq -n --arg lattice_program "$lattice_program" --arg executable_blake3 "$lattice_blake3" \
      --arg state_directory ${lib.escapeShellArg "/var/lib/${runtimeName}/lattice/implementation"} \
      --arg output_directory ${lib.escapeShellArg "/var/lib/${runtimeName}/lattice/observations"} \
      '{schema:"kiln.lattice-implementation-cli.v2",lattice_program:$lattice_program,executable_blake3:$executable_blake3,state_directory:$state_directory,output_directory:$output_directory}' \
      > "$out/campaign-worker-transport-profile.json"
    setpriv=${pkgs.util-linux}/bin/setpriv
    setpriv_blake3="$(b3sum --no-names "$setpriv")"
    cairn_policy_identity="$(b3sum --no-names "$out/cairn-policy.json")"
    cat > "$TMPDIR/selected-campaign-profile.ncl" <<EOF
  let constructor = (import "${./campaign-profile.ncl}").generate in
  constructor
    (import "${selectedCampaignCohort}/manifest.json")
    (import ${builtins.toJSON (toString selectedCampaign)})
    {
      enrollment = "$out/enrollment.json",
      transport_profile = "$out/campaign-worker-transport-profile.json",
      campaign_credential_path = ${if selectedCampaignCredentialPath == null then "null" else builtins.toJSON (toString selectedCampaignCredentialPath)},
      cairn_policy_path = "$out/cairn-policy.json",
      setpriv = "$setpriv",
      setpriv_blake3 = "$setpriv_blake3",
      cairn_policy_identity = "$cairn_policy_identity",
      coordinator_uid = ${toString coordinatorUid},
      executor_uid = ${toString executorUid},
      publisher_uid = ${toString publisherUid},
      verifier_uid = ${toString verifierUid},
      data_gid = ${toString campaignDataGid},
    }
    (import "${selectedCampaignCohort.kiln}/share/kiln/implementation-campaign-drive.ncl")
EOF
    nickel export --format json "$TMPDIR/selected-campaign-profile.ncl" > "$out/campaign-drive-profile.json"
  ''}
''
