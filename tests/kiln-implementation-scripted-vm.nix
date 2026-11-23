{ pkgs, lib, fixture }:
let
  inherit (fixture) cohort campaignCohort configuration attemptBundle ciServiceProfile campaignDriveProfile campaignStartCommand fixtureHelper canonicalCiStatePaths repositories workClasses canonicalCiModule;
  root = "/var/lib/kiln-implementation";
  common = "--database ${root}/kiln/work.sqlite --enrollment ${configuration}/enrollment.json";
  node = scenario: { config, ... }:
    let
      campaignMode = scenario == "campaign";
      selectedCohort = if campaignMode then campaignCohort else cohort;
    in
    {
    imports = [ ../modules/kiln-implementer/nixos.nix canonicalCiModule ];
    system.stateVersion = "26.05";
    virtualisation = { graphics = false; memorySize = 2048; cores = 2; };
    services.kiln-implementer = {
      enable = true;
      cohort = selectedCohort;
      inherit configuration attemptBundle ciServiceProfile canonicalCiStatePaths repositories workClasses;
      intakeCredential = "/run/secrets/kiln-scripted-intake";
      publisherCredential = "/run/secrets/kiln-scripted-publisher";
      modelNetworkNamespace = if campaignMode then null else "/run/netns/kiln-scripted-model";
      selectedCampaignEnable = campaignMode;
      selectedCampaignProfile = if campaignMode then campaignDriveProfile else null;
      selectedCampaignId = if campaignMode then "scripted-native-cairn" else null;
      selectedCampaignDatabase = if campaignMode then "${root}/campaign/campaign.sqlite" else null;
      selectedImplementationDatabase = if campaignMode then "${root}/kiln/work.sqlite" else null;
      selectedCampaignBoundInputDirectory = if campaignMode then "${root}/campaign/bound-input" else null;
      selectedCampaignCandidateExportDirectory = if campaignMode then "${root}/campaign/candidate-export" else null;
      selectedCampaignWorkspaceRoot = if campaignMode then "${root}/campaign/workspaces" else null;
      selectedCampaignDataGid = if campaignMode then 931 else null;
      selectedCampaignNetworkNamespace = if campaignMode then "/run/netns/kiln-scripted-model" else null;
      selectedCampaignCredentialPath = if campaignMode then "/run/kiln-scripted-campaign-publisher" else null;
      leaseMilliseconds = if scenario == "stale" then 1000 else 3600000;
      # The fixture enrollment's actor; claim under an admission policy needs it.
      localOperator = "operator";
    };
    users.groups.kiln-scripted-git = { };
    users.users = {
      kiln-scripted-model = { isSystemUser = true; uid = 934; group = "kiln-scripted-model"; };
      kiln-scripted-forge = { isSystemUser = true; uid = 935; group = "kiln-scripted-git"; };
    };
    users.groups.kiln-scripted-model = { };
    environment.systemPackages = [ pkgs.python3 pkgs.b3sum pkgs.jq pkgs.git pkgs.iproute2 pkgs.procps pkgs.util-linux pkgs.nickel
      (import ../modules/kiln-implementer/qualification-package.nix { inherit pkgs; }) ];
    systemd.services = {
      kiln-scripted-network = {
        description = "Closed fixture loopback namespace; no interface or external route";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          ${pkgs.iproute2}/bin/ip netns add kiln-scripted-model
          ${pkgs.iproute2}/bin/ip -n kiln-scripted-model link set lo up
        '';
        preStop = "${pkgs.iproute2}/bin/ip netns delete kiln-scripted-model";
      };
      kiln-scripted-setup = {
        description = "Initialize only disposable actual Git/credential fixtures";
        wantedBy = [ "multi-user.target" ];
        requires = [ "systemd-tmpfiles-setup.service" ]; after = [ "systemd-tmpfiles-setup.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = ''
          install -d -m 0700 /run/secrets
          printf %s scripted-intake-only > /run/secrets/kiln-scripted-intake
          printf %s scripted-publisher-only > /run/secrets/kiln-scripted-publisher
          chmod 0600 /run/secrets/kiln-scripted-intake /run/secrets/kiln-scripted-publisher
          if ! test -f ${root}/verifier/repository/config; then
            ${pkgs.git}/bin/git clone --bare --no-hardlinks ${fixture}/repository.git ${root}/verifier/repository
            chown -R kiln-implementation-verifier:kiln-implementation-ledger ${root}/verifier
            chmod 0700 ${root}/verifier ${root}/verifier/repository
          fi
          install -d -m 0750 -o kiln-implementation-publisher -g kiln-scripted-git ${root}/github
          if ! test -f ${root}/github/remote.git/config; then
            ${pkgs.git}/bin/git clone --bare --no-hardlinks ${fixture}/repository.git ${root}/github/remote.git
            ${pkgs.git}/bin/git -C ${root}/github/remote.git config core.sharedRepository group
            chown -R kiln-implementation-publisher:kiln-scripted-git ${root}/github/remote.git
            chmod -R g+rwX ${root}/github/remote.git
            find ${root}/github/remote.git -type d -exec chmod g+s {} +
          fi
        '';
      };
      kiln-scripted-campaign-setup = lib.mkIf campaignMode {
        description = "Initialize disposable selected-Cairn state through canonical owner commands";
        wantedBy = [ "multi-user.target" ];
        requires = [ "kiln-scripted-setup.service" "kiln-scripted-network.service" "kiln-implementation-policy-check.service" ];
        after = [ "kiln-scripted-setup.service" "kiln-scripted-network.service" "kiln-implementation-policy-check.service" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; UMask = "0007"; };
        script = ''
          set -eu
          ${pkgs.coreutils}/bin/install -d -m 0755 ${root}/campaign
          ${pkgs.git}/bin/git clone --no-hardlinks ${fixture}/repository.git ${root}/campaign/source
          ${pkgs.git}/bin/git --git-dir=${root}/verifier/repository update-ref refs/remotes/origin/main "$(${pkgs.git}/bin/git --git-dir=${root}/verifier/repository rev-parse refs/heads/main)"
          ${selectedCohort}/environment/bin/kiln-cairn-intake ${common} \
            --snapshot ${attemptBundle}/cairn-snapshot.json --policy ${configuration}/cairn-policy.json --sequence 1
          intake="$(${fixtureHelper}/bin/kiln-implementation-fixture prepare-intake \
            --database ${root}/kiln/work.sqlite --enrollment ${configuration}/enrollment.json)"
          work="$(printf '%s' "$intake" | ${pkgs.jq}/bin/jq -er .work)"
          ${selectedCohort}/environment/bin/kiln-implementer prepare-needs ${common} --work "$work" \
            --needs-file ${fixture}/campaign/work-needs.json --output ${root}/campaign/work-needs.json
          ${selectedCohort}/environment/bin/kiln-implementer attach-needs ${common} \
            --needs-file ${root}/campaign/work-needs.json
          ${pkgs.python3}/bin/python3 ${fixture}/prepare_campaign_plan.py \
            --template ${fixture}/campaign/dispatch-plan-template.json \
            --needs ${root}/campaign/work-needs.json --output ${root}/campaign/dispatch-plan-template.json
          ${selectedCohort}/environment/bin/kiln-implementer admission-status ${common} > ${root}/campaign/admission-status.json
          ${pkgs.coreutils}/bin/chmod 0400 ${root}/campaign/admission-status.json
          ${pkgs.python3}/bin/python3 ${fixture}/prepare_campaign_start.py \
            --template ${campaignStartCommand} --admission-status ${root}/campaign/admission-status.json \
            --manifest ${fixture}/bundle-manifest.json --repository ${fixture}/repository.git \
            --workflow ${fixture}/campaign/workflow-profile.json --policy ${configuration}/cairn-policy.json \
            --integration-policy ${fixture}/campaign/integration-policy.json \
            --agent-definition ${fixture}/campaign/worker-request-template.json --work "$work" \
            --output ${root}/campaign/start-command.json

          ${selectedCohort}/environment/bin/kiln-implementer campaign \
            --database ${root}/campaign/campaign.sqlite --command-file ${root}/campaign/start-command.json
          ${pkgs.coreutils}/bin/install -m 0444 ${fixture}/campaign/remote-template.json ${root}/campaign/remote-template.json
          remote_binding="$(${fixtureHelper}/bin/kiln-implementation-fixture prepare-remote --profile ${root}/campaign/remote-template.json)"
          remote_identity="$(printf '%s' "$remote_binding" | ${pkgs.jq}/bin/jq -er .remote_identity)"
          ${pkgs.jq}/bin/jq -n --arg repository_path ${root}/verifier/repository \
            --arg remote_identity "$remote_identity" --slurpfile remote ${root}/campaign/remote-template.json \
            '{schema:"kiln.github-publication-source.v1",repository_path:$repository_path,remote:$remote[0],remote_identity:$remote_identity,fixture:true}' \
            > ${root}/campaign/publication-source-profile.json
          ${pkgs.coreutils}/bin/chmod 0444 ${root}/campaign/publication-source-profile.json
          printf %s scripted-campaign-only > /run/kiln-scripted-campaign-publisher
          ${pkgs.coreutils}/bin/chown kiln-implementation-publisher:kiln-implementation-ledger /run/kiln-scripted-campaign-publisher
          ${pkgs.coreutils}/bin/chmod 0400 /run/kiln-scripted-campaign-publisher
        '';
      };
      kiln-scripted-model = {
        requires = [ "kiln-scripted-network.service" ]; after = [ "kiln-scripted-network.service" ];
        serviceConfig = {
          Type = "simple"; User = "kiln-scripted-model"; Group = "kiln-scripted-model";
          StateDirectory = "kiln-scripted-model"; StateDirectoryMode = "0700";
          ProtectSystem = "strict"; ProtectHome = true; NoNewPrivileges = true; PrivateTmp = true;
          NetworkNamespacePath = "/run/netns/kiln-scripted-model";
          InaccessiblePaths = [ "/run/secrets" "${root}/kiln" "${root}/verifier" ];
          ExecStart = "${pkgs.python3}/bin/python3 ${fixture}/model_server.py --scenario ${fixture}/scenario.json --evidence /var/lib/kiln-scripted-model/evidence.json --response-delay-seconds ${if builtins.elem scenario [ "cancel" "timeout" ] then "115" else "2"}";
        };
      };
      kiln-scripted-forge = {
        path = [ pkgs.git ];
        serviceConfig = {
          Type = "simple"; User = "kiln-scripted-forge"; Group = "kiln-scripted-git";
          StateDirectory = "kiln-scripted-forge"; StateDirectoryMode = "0700";
          ProtectSystem = "strict"; ProtectHome = true; NoNewPrivileges = true; PrivateTmp = true;
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
          ExecStart = toString (pkgs.writeShellScript "kiln-scripted-forge-bound" ''
            set -eu
            reference="$(${pkgs.jq}/bin/jq -r .claim ${root}/controller/current.json)"
            attempt="''${reference%.json}"
            exec ${pkgs.python3}/bin/python3 ${fixture}/github_fixture.py \
              --publication-plan "${root}/controller/bindings/$attempt/publication/publication.json" \
              --bare-repository ${root}/github/remote.git --state-dir /var/lib/kiln-scripted-forge --port 18701 --drop-pr-response-once
          '');
        };
      };
      kiln-implementation-publish = {
        environment.KILN_GITHUB_FIXTURE_PUBLICATION_ENDPOINT = "http://127.0.0.1:18701";
        serviceConfig = {
          SupplementaryGroups = [ "kiln-scripted-git" ];
          ReadWritePaths = lib.mkAfter [ "${root}/github" ];
        };
      };
      kiln-implementation-cairn-source-change = lib.mkIf (scenario == "sourcechange") {
        requires = [ "kiln-implementation-policy-check.service" ]; after = [ "kiln-implementation-policy-check.service" ];
        serviceConfig = config.systemd.services.kiln-implementation-cairn-intake.serviceConfig // {
          ExecStart = "${selectedCohort}/environment/bin/kiln-cairn-intake ${common} --snapshot ${attemptBundle}/cairn-source-change-snapshot.json --policy ${configuration}/cairn-policy.json --sequence 2";
        };
      };
    };
  };
in
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
assert lib.all (value: lib.hasPrefix "/nix/store/" (toString value)) [ fixture cohort campaignCohort configuration attemptBundle ciServiceProfile campaignDriveProfile ];
pkgs.testers.runNixOSTest {
  name = "kiln-implementation-scripted-vm";
  nodes = lib.genAttrs [ "machine" "cancel" "timeout" "stale" "sourcechange" "campaign" ] node;
  testScript = ''
    import json
    import shlex
    start_all()
    root = "${root}"
    common = "${common}"
    cli = "${cohort}/environment/bin/kiln-implementer"
    campaign_cli = "${campaignCohort}/environment/bin/kiln-implementer"
    campaign_drive_cli = "${campaignCohort}/environment/bin/kiln-web-service"
    nodes = {"primary": machine, "cancel": cancel, "timeout": timeout, "stale": stale, "sourcechange": sourcechange, "campaign": campaign}

    def start(node, stage):
        node.succeed(f"systemctl start kiln-implementation-{stage}.service")

    def status(node):
        return json.loads(node.succeed(f"runuser -u kiln-implementation-coordinator -- {cli} status {common}"))

    def claim(node):
        reference = json.loads(node.succeed(f"cat {root}/controller/current.json"))["claim"]
        return json.loads(node.succeed(f"cat {root}/controller/claims/{reference}"))

    def dispatch_path(node):
        actual = claim(node)
        return f"{root}/controller/bindings/{actual['identity']}-{actual['fence']}/dispatch"

    def intake(node):
        node.wait_for_unit("multi-user.target")
        node.wait_for_unit("kiln-scripted-setup.service")
        node.wait_for_unit("kiln-scripted-network.service")
        # Fail on missing/changed actual consumers before starting any owner stage.
        node.succeed(r"""python3 - <<'PY'
    import json, pathlib, subprocess
    manifest = json.loads(pathlib.Path("${cohort}/manifest.json").read_text())
    for name in ("coordinator", "verifier", "dispatch", "cairn_intake", "lattice", "cairn", "worker", "sandbox", "git", "nix"):
        entry = manifest["entries"][name]
        path = pathlib.Path(entry["resolved_path"])
        assert path.is_file() and path.stat().st_mode & 0o111
        assert str(path.resolve(strict=True)) == entry["resolved_path"]
        assert subprocess.check_output(["b3sum", "--no-names", str(path)], text=True).strip() == entry["blake3"]
    PY""")
        capabilities = node.fail("${cohort}/environment/bin/kiln-implementer")
        for required in ("claim", "inspect-attempt", "reserve-plan", "capture-candidate", "prepare-publication", "publish"):
            assert required in capabilities, capabilities
        route = node.fail("${cohort}/environment/bin/kiln-lattice-dispatch --worker-request ${attemptBundle}/runtime-template.json")
        assert "--dispatch-plan is required" in route, route
        lattice_help = node.succeed("${cohort}/environment/bin/lattice implementation-attempt --help")
        assert all(command in lattice_help for command in ("prepare", "run", "recover", "cancel")), lattice_help
        verifier_help = node.succeed("${cohort}/environment/bin/kiln-web-service verify-implementation --help")
        assert "--verification-profile" in verifier_help and "--authority" in verifier_help, verifier_help
        node.succeed("${cohort}/environment/bin/cairn --help")
        node.succeed("${cohort}/environment/bin/omp --help")
        start(node, "cairn-intake")
        start(node, "cairn-intake")
        assert status(node)["work"] == 1
        start(node, "prepare-fixture-intake")
        # The registered host-local owner (fixture host-owner.json) admits and
        # observes before the claim, as on the live pilot.
        start(node, "host-owner-admit")
        start(node, "host-owner-observe")
        start(node, "claim")
        actual = claim(node)
        assert actual["claimed_at_ms"] > 0 and actual["lease_until_ms"] > actual["claimed_at_ms"]
        assert status(node)["attempts"] == 1
        return actual

    def prepare(node):
        actual = intake(node)
        # A reserved attempt: Kiln sends Lattice the admitted request plus one
        # budget `lineage`, so recover, export and cancel must name that file.
        start(node, "host-owner-reserve")
        start(node, "host-owner-observe")
        start(node, "bind-dispatch")
        bound = dispatch_path(node)
        node.succeed(f"test ! -e {bound}/publication.json")
        node.succeed(f"runuser -u kiln-implementation-executor -- test ! -w {bound}/attempt.json")
        node.succeed(f"runuser -u kiln-implementation-executor -- test ! -w {root}/controller")
        node.succeed("runuser -u kiln-implementation-executor -- test ! -r /run/secrets/kiln-scripted-publisher")
        node.succeed("runuser -u kiln-implementation-executor -- test ! -w ${configuration}")
        node.succeed("runuser -u kiln-implementation-executor -- test ! -w ${ciServiceProfile}")
        node.succeed(f"runuser -u kiln-implementation-executor -- test ! -r {root}/verifier/repository")
        start(node, "reserve")
        node.succeed("systemctl start kiln-scripted-model.service")
        node.wait_until_succeeds("ip netns exec kiln-scripted-model ss -ltn | grep -F 127.0.0.1:18700")
        return actual

    def observation(node):
        return json.loads(node.succeed("python3 -c " + shlex.quote("import json,pathlib; print(pathlib.Path('/var/log/kiln-implementation-executor/dispatch.jsonl').read_text().splitlines()[-1])")))

    # One real OMP edit -> independently protected actual checks -> actual Git
    # objects/ref -> one stateful local PR, including lost-effect reconciliation.
    actual = prepare(machine)
    machine.succeed("systemctl start --no-block kiln-implementation-dispatch.service")
    machine.wait_until_succeeds("test -s /var/lib/kiln-scripted-model/evidence.json", timeout=60)
    main_pid = int(machine.succeed("systemctl show kiln-implementation-dispatch.service -p MainPID --value"))
    assert main_pid > 1
    # Stop only the dispatcher, allowing its actual native Lattice child to
    # finish and durably publish the worker result before acknowledgement loss.
    machine.succeed("systemctl kill --kill-whom=main --signal=SIGSTOP kiln-implementation-dispatch.service")
    machine.wait_until_succeeds(f"ps -o stat= --ppid {main_pid} | grep -q '^Z'", timeout=60)
    machine.succeed("systemctl kill --kill-whom=main --signal=SIGKILL kiln-implementation-dispatch.service")
    machine.wait_until_succeeds("test $(systemctl show kiln-implementation-dispatch.service -p ActiveState --value) = failed")
    machine.succeed("systemctl reset-failed kiln-implementation-dispatch.service")
    start(machine, "recover-dispatch")
    result = observation(machine)
    assert result["result"]["disposition"] == "produced", result
    workspace = json.loads(machine.succeed(f"cat {dispatch_path(machine)}/attempt.json"))["workspace_root"]
    model = json.loads(machine.succeed("cat /var/lib/kiln-scripted-model/evidence.json"))
    assert model["events"][-1] == {"outcome": "completed", "requests": 2}, model
    assert sum("request_sha256" in event for event in model["events"]) == 2, model
    machine.succeed(f"test $(wc -c < {workspace}/src/scripted_model_result.txt) = 41")
    # Kiln's read-only resolution: the recorded request carries the lineage
    # that export-candidate and cancel-worker must hand to Lattice.
    sent = json.loads(machine.succeed(
        "runuser -u kiln-implementation-executor -g kiln-implementation-ledger -- "
        f"${cohort}/environment/bin/kiln-lattice-dispatch {common} --worker-request {dispatch_path(machine)}/attempt.json "
        "--worker-transport-profile ${configuration}/worker-transport-profile.json --sent-request true"))
    assert sent["schema"] == "kiln.lattice-sent-request.v1" and sent["recorded"] is True, sent
    assert "lineage" in json.loads(machine.succeed(f"cat {sent['request']}")), sent
    start(machine, "recover-dispatch")
    assert status(machine)["attempts"] == 1
    start(machine, "claim")
    assert status(machine)["attempts"] == 1
    start(machine, "export-candidate")
    start(machine, "capture-candidate")
    start(machine, "verify")
    start(machine, "verify")
    assert status(machine)["verified"] == 1
    start(machine, "bind-publication")
    start(machine, "prepare-publication")
    machine.succeed("systemctl start kiln-scripted-forge.service")
    machine.wait_for_open_port(18701)
    publication_path = dispatch_path(machine).rsplit('/', 1)[0] + "/publication/publication.json"
    publication = json.loads(machine.succeed(f"cat {publication_path}"))
    # A real target movement must be refused before a PR, not silently accepted.
    base = publication["base"]["native_id"]
    # Create a distinct real target object from the same baseline tree.
    moved = machine.succeed(f"GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid git -c safe.directory={root}/github/remote.git -C {root}/github/remote.git commit-tree {base}^{{tree}} -p {base} -m 'target moved'").strip()
    machine.succeed(f"git -c safe.directory={root}/github/remote.git -C {root}/github/remote.git update-ref refs/heads/main {moved} {base}")
    machine.fail("systemctl start kiln-implementation-publish.service")
    state = json.loads(machine.succeed("cat /var/lib/kiln-scripted-forge/state.json"))
    assert state["pull_request"] is None
    machine.succeed(f"git -c safe.directory={root}/github/remote.git -C {root}/github/remote.git update-ref refs/heads/main {base} {moved}")
    machine.succeed("systemctl reset-failed kiln-implementation-publish.service")
    # The fixture creates the PR and drops its first response. The native shell
    # must reconcile the retained effect rather than issuing another POST.
    machine.execute("systemctl start kiln-implementation-publish.service")
    machine.succeed("systemctl reset-failed kiln-implementation-publish.service")
    start(machine, "publish")
    machine.succeed("systemctl restart kiln-scripted-forge.service")
    machine.wait_for_open_port(18701)
    start(machine, "publish")
    assert status(machine)["published"] == 1
    machine.succeed(r"""python3 - <<'PY'
    import json,pathlib,subprocess
    state=json.loads(pathlib.Path('/var/lib/kiln-scripted-forge/state.json').read_text())
    events=[json.loads(line) for line in pathlib.Path('/var/lib/kiln-scripted-forge/events.jsonl').read_text().splitlines()]
    assert state['dropped_pr_response'] and state['pull_request']['number']==1
    assert sum(event['method']=='POST' and event['path'].endswith('/pulls') and event['status']==201 for event in events)==1
    head=subprocess.check_output(['git','-c','safe.directory=${root}/github/remote.git','-C','${root}/github/remote.git','rev-parse','refs/heads/'+state['branch']],text=True).strip()
    assert head==state['candidate']==state['pull_request']['head']['sha']
    subprocess.run(['git','-c','safe.directory=${root}/github/remote.git','-C','${root}/github/remote.git','cat-file','-e',head+'^{commit}'],check=True)
    PY""")

    # Real monotonic elapsed host time, never a test clock or pre-minted lease.
    expired = intake(stale)
    stale.wait_until_succeeds(f"test $(date +%s%3N) -ge {expired['lease_until_ms']}")
    stale.fail("systemctl start kiln-implementation-bind-dispatch.service")
    stale.fail(f"runuser -u kiln-implementation-coordinator -- {cli} renew {common} --attempt {expired['identity']} --fence {expired['fence']} --lease-ms 1000")
    assert status(stale)["verified"] == 0

    old = intake(sourcechange)
    start(sourcechange, "cairn-source-change")
    sourcechange.fail("systemctl start kiln-implementation-bind-dispatch.service")
    sourcechange.fail(f"runuser -u kiln-implementation-coordinator -- {cli} renew {common} --attempt {old['identity']} --fence {old['fence']} --lease-ms 1000")
    assert status(sourcechange)["superseded"] == 1

    prepare(cancel)
    cancel.succeed("systemctl start --no-block kiln-implementation-dispatch.service")
    cancel.wait_until_succeeds("test -s /var/lib/kiln-scripted-model/evidence.json", timeout=60)
    # Inspect the actual live child mount namespace and UID. Policy/check roots
    # and publisher credentials are absent; .omp is an actual read-only mount.
    cancel.succeed(r"""python3 - <<'PY'
    from pathlib import Path
    found=[]
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal(): continue
        try:
            status=(proc/'status').read_text()
            child_root=proc/'root'
            # Lattice v3 mounts its generated read-only OMP model config here.
            if 'Uid:\t931\t' not in status or not (child_root/'tmp/omp-home/.omp/agent/models.yml').is_file(): continue
            assert not (child_root/'run/secrets').exists()
            assert not (child_root/'var/lib/kiln-implementation/controller').exists()
            assert not (child_root/'var/lib/kiln-implementation/verifier').exists()
            assert not (child_root/'var/lib/kiln-implementation/kiln').exists()
            mounts=(proc/'mountinfo').read_text().splitlines()
            for protected in ('/workspace/.cairn','/workspace/src','/nix/store','/tmp/omp-home/.omp/agent/models.yml'):
                assert any(row.split()[4]==protected and 'ro' in row.split()[5].split(',') for row in mounts), protected
            assert any(row.split()[4]=='/workspace/src/scripted_model_result.txt' and 'rw' in row.split()[5].split(',') for row in mounts)
            assert b'CREDENTIALS_DIRECTORY=' not in (proc/'environ').read_bytes()
            # No network device: only loopback exists in the worker namespace.
            interfaces=[line.split(':')[0].strip() for line in (proc/'net/dev').read_text().splitlines()[2:]]
            assert interfaces==['lo'], interfaces
            found.append(proc.name)
        except (FileNotFoundError,ProcessLookupError,PermissionError): pass
    assert found, 'actual isolated editing child was not observed'
    Path('/var/lib/kiln-scripted-model/observed-child-pids.json').write_text(__import__('json').dumps(found))
    PY""")
    start(cancel, "cancel-worker")
    cancel.wait_until_succeeds("test $(systemctl show kiln-implementation-dispatch.service -p ActiveState --value) != activating", timeout=60)
    cancelled = observation(cancel)
    assert cancelled["result"]["disposition"] == "cancelled", cancelled
    assert status(cancel)["cancelled"] == 1 and status(cancel)["verified"] == 0
    cancel.succeed("! pgrep -u 931")
    cancel.fail("systemctl start kiln-implementation-export-candidate.service")

    prepare(timeout)
    timeout.succeed("systemctl start --no-block kiln-implementation-dispatch.service")
    timeout.wait_until_succeeds("test -s /var/lib/kiln-scripted-model/evidence.json", timeout=60)
    timeout.wait_until_succeeds("test $(systemctl show kiln-implementation-dispatch.service -p ActiveState --value) != activating", timeout=150)
    timed = observation(timeout)
    assert timed["result"]["disposition"] != "produced", timed
    assert any(word in json.dumps(timed["result"]).lower() for word in ("timed out", "timeout")), timed
    assert status(timeout)["verified"] == 0 and status(timeout)["published"] == 0
    timeout.succeed("! pgrep -u 931")
    timeout.fail("systemctl start kiln-implementation-export-candidate.service")

    campaign.wait_for_unit("kiln-scripted-campaign-setup.service")
    campaign.succeed("systemctl start kiln-scripted-model.service")
    campaign.wait_until_succeeds("ip netns exec kiln-scripted-model ss -ltn | grep -F 127.0.0.1:18700")
    unsupported_id = "scripted-unsupported-github-lifecycle"
    unsupported_start = json.loads(campaign.succeed(f"cat {root}/campaign/start-command.json"))
    unsupported_start["contract"]["campaign_id"] = unsupported_id
    unsupported_start["contract"]["members"][0]["goal"] = "native_lifecycle_complete"
    campaign.succeed(f"printf '%s' {shlex.quote(json.dumps(unsupported_start))} > /tmp/unsupported-campaign-start.json")
    campaign.succeed(f"{campaign_cli} campaign --database {root}/campaign/campaign.sqlite --command-file /tmp/unsupported-campaign-start.json")
    unsupported_profile = json.loads(open("${fixture}/campaign/drive-profile.json").read())
    unsupported_profile["campaign_id"] = unsupported_id
    campaign.succeed(f"printf '%s' {shlex.quote(json.dumps(unsupported_profile))} > /tmp/unsupported-campaign-profile.json")
    unsupported_inspect = json.dumps({"command": "inspect", "campaign_id": unsupported_id})
    campaign.succeed(f"printf '%s' {shlex.quote(unsupported_inspect)} > /tmp/unsupported-campaign-inspect.json")
    unsupported_version = json.loads(campaign.succeed(f"{campaign_cli} campaign --database {root}/campaign/campaign.sqlite --command-file /tmp/unsupported-campaign-inspect.json"))["store_version"]
    endpoint_refusal = campaign.fail(f"{campaign_drive_cli} drive-implementation-campaign --profile /tmp/unsupported-campaign-profile.json --campaign-id {unsupported_id} --expected-version {unsupported_version}")
    assert "selected delivery route cannot reach a frozen campaign endpoint" in endpoint_refusal, endpoint_refusal
    assert status(campaign)["attempts"] == 0, status(campaign)
    campaign.succeed(f"test $(stat -c %a {root}/campaign/admission-status.json) = 400")
    campaign.succeed(f"test $(stat -c %a {root}/campaign/start-command.json) = 600")
    campaign.succeed("test ! -e /var/lib/kiln-scripted-model/evidence.json")
    campaign.succeed("test -f /var/lib/kiln-implementation/campaign/campaign.sqlite")
    campaign.succeed("test -f /var/lib/kiln-implementation/campaign/work-needs.json")
    campaign.succeed("test -f /var/lib/kiln-implementation/campaign/dispatch-plan-template.json")
    campaign.succeed("test -f /var/lib/kiln-implementation/campaign/publication-source-profile.json")
    inspect_json = json.dumps({"command": "inspect", "campaign_id": "scripted-native-cairn"})
    campaign.succeed(f"printf '%s' {shlex.quote(inspect_json)} > /tmp/campaign-inspect.json")
    inspect_command = f"{campaign_cli} campaign --database {root}/campaign/campaign.sqlite --command-file /tmp/campaign-inspect.json"
    initial = json.loads(campaign.succeed(inspect_command))
    assert isinstance(initial["store_version"], int) and initial["store_version"] > 0, initial
    initial_version = initial["store_version"]
    campaign.succeed(f"systemctl start kiln-implementation-drive-selected-campaign@{initial_version}.service")
    after_drive = json.loads(campaign.succeed(inspect_command))
    state = after_drive["campaign"]
    observations = list(state["observations"].values())
    assert len(observations) == 1, state
    member = observations[0]
    assert member["stage"] == "verified_candidate", member
    assert member["work_identity"] and member["source_identity"] and member["attempt_identity"] and member["attempt_fence"] > 0, member
    assert member["context_identity"] and member["native_context_identity"] and member["policy_identity"], member
    assert isinstance(member["remaining_obligations"], list) and member["required_checks_satisfied"], member
    drive_profile = json.loads(open("${fixture}/campaign/drive-profile.json").read())
    integration_policy = json.loads(open("${fixture}/campaign/integration-policy.json").read())
    assert integration_policy["route"] == drive_profile["delivery"]["route"]
    assert integration_policy["base_branch"] == drive_profile["delivery"]["github"]["publication_policy"]["base_branch"]
    assert integration_policy["required_checks"] == drive_profile["delivery"]["github"]["landing_policy"]["required_checks"]
    assert integration_policy["required_approvals"] == drive_profile["delivery"]["github"]["landing_policy"]["required_approvals"]
    assert integration_policy["lifecycle_action"] == drive_profile["delivery"]["github"]["lifecycle_action"]
    workflow_material = json.loads(open("${fixture}/campaign/workflow-profile.json").read())
    assert workflow_material["schema"] == "kiln.scripted-workflow-profile.v1"
    assert workflow_material["profile"] == "spec_driven"
    assert workflow_material["campaign_workflow_blake3"] == campaign.succeed("b3sum --no-names ${campaignCohort}/workflow.ncl").strip()
    assert workflow_material["implementation_profile_blake3"] == campaign.succeed("b3sum --no-names ${fixture}/profile.ncl").strip()
    assert len(drive_profile["decision_contexts"]) == 1, drive_profile["decision_contexts"]
    projection_identity, projection_path = next(iter(drive_profile["decision_contexts"].items()))
    projection_bytes = open(projection_path, "rb").read()
    assert campaign.succeed(f"b3sum --no-names {shlex.quote(projection_path)}").strip() == projection_identity
    start_command = json.loads(campaign.succeed(f"cat {root}/campaign/start-command.json"))
    contract = start_command["contract"]
    binding = contract["members"][0]["context"][0]
    assert binding == {
        "decision_id": "scripted-operator-choice",
        "native_adr_id": None,
        "revision": "fixture-revision-1",
        "selected_alternative": "write-only-authorized-output",
        "evidence": [],
        "supersedes": [],
        "projection_identity": projection_identity,
        "required": True,
    }, binding
    admission = json.loads(campaign.succeed(f"cat {root}/campaign/admission-status.json"))
    account_id = admission["items"][member["work_identity"]]["account"]
    account = admission["accounts"][account_id]
    assert contract["parent_budget_id"] == account_id == account["identity"], account
    assert account["parent"] is None and account["parent_attempt"] is None, account
    workflow_identity = campaign.succeed("b3sum --no-names ${fixture}/campaign/workflow-profile.json").strip()
    policy_identity = campaign.succeed("b3sum --no-names ${configuration}/cairn-policy.json").strip()
    integration_identity = campaign.succeed("b3sum --no-names ${fixture}/campaign/integration-policy.json").strip()
    agent_identity = campaign.succeed("b3sum --no-names ${fixture}/campaign/worker-request-template.json").strip()
    base = json.loads(open("${fixture}/bundle-manifest.json").read())["base"]["native_id"]
    change = contract["members"][0]["selector"]["change"]
    instruction_identity = campaign.succeed(
        f"git --git-dir=${fixture}/repository.git show {base}:.cairn/changes/{change}/tasks.md | b3sum --no-names"
    ).strip()
    member_contract = contract["members"][0]
    assert member_contract["required_checks"] == integration_policy["required_checks"]
    assert member_contract["required_reviews"] == integration_policy["required_reviews"]
    assert member_contract["profile_version"] == workflow_identity, member_contract
    assert member_contract["repository_instructions"] == instruction_identity, member_contract
    assert member_contract["policy"] == policy_identity, member_contract
    assert member_contract["integration_policy"] == integration_identity, member_contract
    assert contract["agent_definition"] == agent_identity, contract
    retained = state["attempt_contexts"][member["attempt_identity"]][projection_identity]
    assert bytes(retained["exact_manifest"]) == projection_bytes, retained
    assert retained["decision_revisions"] == [binding["revision"]], retained
    request_path = f"{root}/campaign/bound-input/campaign-{member['attempt_identity']}.request.json"
    prepared_request = json.loads(campaign.succeed(f"cat {request_path}"))
    prompt = prepared_request["omp"]["prompt"]
    marker = "\n\n[Kiln native Cairn stage context "
    marker_start = prompt.index(marker)
    marker_end = prompt.index("]\n", marker_start) + 2
    stage_context = json.loads(prompt[marker_end:])
    decision_context = stage_context["decision_context"]
    assert decision_context["bindings"][0]["projection_identity"] == projection_identity, decision_context
    retained_projection = next(item for item in decision_context["projections"] if item["identity"] == projection_identity)
    assert retained_projection["status"] == "retained" and retained_projection["encoding"] == "utf8", retained_projection
    assert retained_projection["manifest"].encode("utf-8") == projection_bytes, retained_projection
    assert status(campaign)["verified"] == 1, status(campaign)
    assert campaign.succeed(f"find {root}/campaign/candidate-export -type f -print -quit").strip()
    baseline = json.loads(open("${fixture}/bundle-manifest.json").read())["base"]["native_id"]
    for repository_path in (f"{root}/verifier/repository", f"{root}/github/remote.git"):
        current = campaign.succeed(f"git --git-dir={repository_path} rev-parse refs/heads/main").strip()
        assert current == baseline, (repository_path, current, baseline)
    campaign.fail(f"systemctl start kiln-implementation-drive-selected-campaign@{initial_version}.service")
    after_stale = json.loads(campaign.succeed(inspect_command))
    assert after_stale["store_version"] == after_drive["store_version"], after_stale
    campaign.succeed(f"systemctl start kiln-implementation-drive-selected-campaign@{after_drive['store_version']}.service")
    after_restart = json.loads(campaign.succeed(inspect_command))
    assert status(campaign)["attempts"] == 1, status(campaign)
    assert after_restart["campaign"]["observations"] == state["observations"], after_restart
    assert after_restart["campaign"]["attempt_contexts"][member["attempt_identity"]][projection_identity] == retained, after_restart
    for name, node in nodes.items():
        assert json.loads(node.succeed("cat /etc/kiln-implementation/deployment.json"))["qualification"] == "unqualified"
        paths = ["var/lib/kiln-implementation", "${fixture}/bundle-manifest.json"]
        for extra in ("var/lib/kiln-scripted-model", "var/lib/kiln-scripted-forge", "var/log/kiln-implementation-executor", "var/log/kiln-implementation-verifier", "var/log/kiln-implementation-publisher"):
            if node.execute("test -d /" + extra)[0] == 0:
                paths.append(extra)
        node.succeed(f"tar -C / -cf /tmp/{name}-scripted-evidence.tar " + " ".join(shlex.quote(path) for path in paths))
        node.copy_from_vm(f"/tmp/{name}-scripted-evidence.tar")
  '';
}
