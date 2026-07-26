let default_bot_port = 18776 in
let default_check_name = "onix/ci/v1" in
let default_timeout_ms = 900000 in
let default_output_max_bytes = 1048576 in
let default_artifact_max_bytes = 67108864 in
let default_memory_max_bytes = 8589934592 in
let default_cpu_quota_percent = 200 in
let default_parallel_jobs = 2 in
let default_poll_interval_ms = 25 in
let default_teardown_timeout_ms = 5000 in
{
  default = {
    expectedHost = { type = "string", description = "Exact host admitted to run the pilot CI services" },
    deploymentTarget = { type = "string", description = "Pinned operator deployment target" },
    rid = { type = "string", description = "Single admitted public Radicle repository ID" },
    signedRefsFeature = { type = "enum", values = ["parent"], default = "parent", description = "Required signed-reference feature level" },
    productionSeedNodeId = { type = "string", description = "Pinned production seed node ID" },
    productionSeedAddress = { type = "string", description = "Pinned production seed native address" },
    reviewedCommit = { type = "string", description = "Reviewed source revision preserved by the pilot" },
    policyBlake3 = { type = "string", description = "BLAKE3 identity of the accepted portable CI policy" },
    checkName = { type = "string", default = default_check_name, description = "Exact machine-readable signed status check name" },
    expectedBotPublicKey = { type = "string", description = "Pinned generated CI bot Ed25519 public key" },
    expectedBotNodeId = { type = "string", description = "Pinned generated CI bot node ID" },
    expectedBotFingerprint = { type = "string", description = "Pinned generated CI bot SHA-256 fingerprint" },
    delegates = { type = "array_string", description = "Exact project delegate DID set; the CI bot must not appear" },
    cargoTomlBlake3 = { type = "string", description = "Expected Cargo.toml BLAKE3 at admitted objects" },
    cargoLockBlake3 = { type = "string", description = "Expected Cargo.lock BLAKE3 at admitted objects" },
    flakeNixBlake3 = { type = "string", description = "Expected flake.nix BLAKE3 at admitted objects" },
    flakeLockBlake3 = { type = "string", description = "Expected flake.lock BLAKE3 at admitted objects" },
    botListenPort = { type = "port", default = default_bot_port, description = "Loopback-only CI bot node port" },
    scanSchedule = { type = "string", default = "*-*-* *:*:00", description = "Systemd calendar for source synchronization and scanning" },
    timeoutMs = { type = "number", default = default_timeout_ms, description = "Bounded process deadline" },
    stdoutMaxBytes = { type = "number", default = default_output_max_bytes, description = "Retained stdout bound" },
    stderrMaxBytes = { type = "number", default = default_output_max_bytes, description = "Retained stderr bound" },
    artifactMaxBytes = { type = "number", default = default_artifact_max_bytes, description = "External artifact bound" },
    memoryMaxBytes = { type = "number", default = default_memory_max_bytes, description = "Runner memory bound" },
    cpuQuotaPercent = { type = "number", default = default_cpu_quota_percent, description = "Runner CPU quota percentage" },
    maxParallelJobs = { type = "number", default = default_parallel_jobs, description = "Accepted policy parallel-job ceiling" },
    pollIntervalMs = { type = "number", default = default_poll_interval_ms, description = "Bounded child polling interval" },
    teardownTimeoutMs = { type = "number", default = default_teardown_timeout_ms, description = "Bounded child teardown allowance" },
  },
}
