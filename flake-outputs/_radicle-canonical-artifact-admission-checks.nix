# r[verify onix.radicle_source_admission.evidence]
{ self, pkgs, lib, system, ... }:
let
  wasm = import ../lib/wasm.nix { plugins = self.packages.${system}.wasm-plugins; };
  source = ../evidence/radicle/canonical-artifact-source-admission-v1.ncl;
  jsonPath = ../evidence/radicle/canonical-artifact-source-admission-v1.json;
  hashPath = ../evidence/radicle/canonical-artifact-source-admission-v1.blake3;
  receipt = wasm.evalNickelFile source;
  exported = builtins.fromJSON (builtins.readFile jsonPath);
  expectedHash = lib.removeSuffix "\n" (builtins.readFile hashPath);
  expectedPublic = [
    "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo"
    "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f"
    "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a"
    "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF"
    "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM"
    "rad:z2JQ8ihZZ6wraULQPzFWMh25B29rZ"
    "rad:z25ySMy8Hh3HpsxP5zcYoYgaMBi99"
  ];
  expectedPrivate = [
    "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg"
    "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk"
    "rad:z3hRCegTsS8jpJVgxYfb9psEzxHpG"
    "rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3"
  ];
  expectedObjects = [
    {
      revision = "e41340bec587b6d049b5cc518ec7db925dde84be";
      object_type = "commit";
      archive_bytes = 552960;
      archive_blake3 = "8fc65f3d7968d76af419f08ac972955514c8256f8aa5ed90815d8bdcced28113";
    }
    {
      revision = "c932138d880ddf4c2967f4c024b489b5c0022bf1";
      object_type = "commit";
      archive_bytes = 849920;
      archive_blake3 = "3878cdb892bfd4a8eac5779023ba32871d61bc3e8ec7c9ef5f7ab790a8acfeb9";
    }
  ];
  identityMatches = candidate:
    candidate.schema_version == 1
    && candidate.receipt_type == "onix.radicle-canonical-artifact-source-admission.v1"
    && candidate.repository.rid == lib.last expectedPublic
    && candidate.repository.https_url == "https://git.onix.computer/z25ySMy8Hh3HpsxP5zcYoYgaMBi99.git"
    && candidate.repository.default_main == "eb85ddcd9d5c782044a81ed980c1824438bb46c1"
    && map (object: removeAttrs object [ "acquisition" ]) candidate.repository.objects == expectedObjects
    && candidate.producer.identity_revision == "918974c9e5647f38b1381390c2bc4c380c0b823f"
    && candidate.producer.author_sigrefs == "984e0f72a4e27904beeae05d79563041ef614014"
    && candidate.producer.delegates == [ "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx" ]
    && candidate.producer.threshold == 1
    && candidate.producer.signed_refs_feature == "parent"
    && candidate.producer.visibility == "public-parent-observed"
    && candidate.producer.publication_authority == "operator-authorized"
    && candidate.producer.hosting_authority == "operator-authorized-scoped-hosting-deployment"
    && candidate.policy.public_rids == expectedPublic
    && candidate.policy.https_rids == expectedPublic
    && candidate.policy.private_rids == expectedPrivate
    && candidate.policy.ci_rids == [ (builtins.head expectedPublic) ]
    && candidate.deployment.native_desired_count == 11
    && candidate.deployment.public_https_count == 7
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence
    && builtins.all (claim: builtins.elem claim candidate.non_claims) [
      "artifact-correctness" "consumer-correctness" "release-eligibility"
      "seed-delegate-authority" "indefinite-availability" "whole-stack-correctness"
    ];
  admissionAccepted = candidate:
    identityMatches candidate
    && candidate.status == "accepted"
    && candidate.blockers == [ ]
    && candidate.deployment.runtime_overrides == "absent"
    && candidate.deployment.reconcile == "exact-eleven-verified"
    && candidate.deployment.signed_state_import == "verified"
    && map (role: role.host) candidate.deployment.roles == [ "aspen1" "britton-desktop" "aspen3" ]
    && builtins.all (role: role.deployment == "verified" && lib.hasPrefix "/nix/store/" role.observed_closure) candidate.deployment.roles
    && builtins.all (object: object.acquisition == "fresh-anonymous-https-verified") candidate.repository.objects
    && candidate.probes.exact_https == "both-exact-objects-verified"
    && candidate.probes.private_rid == "rejected-404"
    && candidate.probes.unknown_rid == "rejected-404"
    && candidate.probes.unknown_ref == "rejected"
    && candidate.probes.receive_pack == "rejected-404"
    && candidate.probes.wrong_service == "rejected-404"
    && candidate.probes.endpoint_root == "rejected-404";
  blockedRecordMatches = candidate:
    identityMatches candidate
    && candidate.status == "blocked"
    && candidate.blockers != [ ]
    && candidate.deployment.reconcile == "not-performed"
    && candidate.deployment.signed_state_import == "not-performed"
    && builtins.all (role: role.deployment == "not-performed") candidate.deployment.roles
    && builtins.all (object: object.acquisition == "existing-local-signed-storage-not-anonymous-https") candidate.repository.objects
    && candidate.probes.exact_https == "not-repeated-known-post-publication-failure"
    && builtins.all (claim: builtins.elem claim candidate.non_claims) [ "anonymous-acquisition" "deployed-catalog" "replica-convergence" ];
  evidenceCheck =
    assert lib.assertMsg (receipt == exported) "canonical Artifact Nickel and JSON evidence differ";
    assert lib.assertMsg (blockedRecordMatches receipt || admissionAccepted receipt) "canonical Artifact observation record is inconsistent";
    assert lib.assertMsg (receipt.status != "blocked" || !(admissionAccepted (receipt // { status = "accepted"; blockers = [ ]; }))) "changing status alone accepted unobserved Artifact deployment";
    pkgs.runCommand "radicle-canonical-artifact-source-evidence" { nativeBuildInputs = [ pkgs.b3sum ]; } ''
      test "$(b3sum ${jsonPath} | cut -d ' ' -f 1)" = ${lib.escapeShellArg expectedHash}
      printf '%s\n' 'evidence=consistent-observation-record' 'admission=${receipt.status}' > "$out"
    '';
in
{
  checks.radicle-canonical-artifact-source-evidence = evidenceCheck;
  checks.radicle-canonical-artifact-source-admission =
    assert lib.assertMsg (admissionAccepted receipt)
      "canonical Artifact admission blocked: no evidenced deployed baseline or anonymous exact-object acquisition";
    evidenceCheck;
}
