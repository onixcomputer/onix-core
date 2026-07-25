# r[verify onix.radicle_ci.configuration]
# r[verify onix.radicle_ci.validation]
let sc = import "../settings-contracts.ncl" in
let accepted_port = 18776 in
let accepted_timeout_ms = 900000 in
let accepted_output_bytes = 1048576 in
let accepted_artifact_bytes = 67108864 in
let accepted_memory_bytes = 8589934592 in
let accepted_cpu_percent = 200 in
let accepted_parallel_jobs = 2 in
let accepted_poll_ms = 25 in
let accepted_teardown_ms = 5000 in
{
  positive =
    sc.validate_fields
      "radicle-ci-runner:default"
      "radicle-ci-runner-positive"
      {
        expectedHost = "aspen1",
        deploymentTarget = "root@aspen1.local",
        rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo",
        signedRefsFeature = "parent",
        productionSeedNodeId = "z6Mkseed",
        productionSeedAddress = "100.100.103.95:8776",
        reviewedCommit = "29dac88ecded94457572db3fdfaaaab95fa91525",
        policyBlake3 = "091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740",
        expectedBotPublicKey = "ssh-ed25519 AAAA",
        expectedBotNodeId = "z6Mkbot",
        expectedBotFingerprint = "SHA256:bot",
        delegates = ["did:key:z6Mkdelegate"],
        cargoTomlBlake3 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        cargoLockBlake3 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        flakeNixBlake3 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        flakeLockBlake3 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        botListenPort = accepted_port,
        scanSchedule = "*-*-* *:*:00",
        timeoutMs = accepted_timeout_ms,
        stdoutMaxBytes = accepted_output_bytes,
        stderrMaxBytes = accepted_output_bytes,
        artifactMaxBytes = accepted_artifact_bytes,
        memoryMaxBytes = accepted_memory_bytes,
        cpuQuotaPercent = accepted_cpu_percent,
        maxParallelJobs = accepted_parallel_jobs,
        pollIntervalMs = accepted_poll_ms,
        teardownTimeoutMs = accepted_teardown_ms,
      },
  negative =
    sc.validate_fields
      "radicle-ci-runner:default"
      "radicle-ci-runner-negative"
      {
        expectedHost = 1,
        deploymentTarget = false,
        rid = [],
        signedRefsFeature = "leaf",
        productionSeedNodeId = false,
        productionSeedAddress = 1,
        reviewedCommit = false,
        policyBlake3 = [],
        expectedBotPublicKey = false,
        expectedBotNodeId = 1,
        expectedBotFingerprint = [],
        delegates = [1],
        cargoTomlBlake3 = false,
        cargoLockBlake3 = 1,
        flakeNixBlake3 = [],
        flakeLockBlake3 = false,
        botListenPort = "not-a-port",
        scanSchedule = false,
        timeoutMs = "unbounded",
        stdoutMaxBytes = false,
        stderrMaxBytes = [],
        artifactMaxBytes = "unbounded",
        memoryMaxBytes = false,
        cpuQuotaPercent = [],
        maxParallelJobs = "many",
        pollIntervalMs = false,
        teardownTimeoutMs = [],
      },
}
