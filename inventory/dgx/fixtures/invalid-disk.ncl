let { DgxMachines, .. } = import "../contracts.ncl" in

{
  machines.fixture-dgx = {
    name = "fixture-dgx",
    system = "aarch64-linux",
    targetHost = "root@fixture-dgx",
    diskById = "/dev/nvme0n1",
    diskoModule = ".machines/fixture-dgx/disko.nix",
    facterReport = ".machines/fixture-dgx/facter.json",
    knownHostsFile = ".machines/fixture-dgx/known_hosts",
    sshHostFingerprint = "SHA256:ZmFrZQ==",
    accessPolicy = "framework-only",
    runtimeSecrets = {
      tailscaleAuthKey = "DGX_FIXTURE_TAILSCALE_AUTH_KEY",
      meshJoinToken = "DGX_FIXTURE_MESH_JOIN_TOKEN",
      irohPrivateKey = "DGX_FIXTURE_IROH_PRIVATE_KEY",
      irohPublicKey = "DGX_FIXTURE_IROH_PUBLIC_KEY",
    },
    meshBackend = {
      unit = "fixture-openai-backend.service",
      externallyManaged = false,
    },
  },
} | DgxMachines
