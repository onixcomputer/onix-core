{
  master = {
    domain = { type = "string", description = "Buildbot web UI domain" },
    useHTTPS = { type = "bool", default = true, description = "Enable HTTPS via ACME" },
    buildSystems = { type = "array_string", default = ["x86_64-linux"], description = "Nix systems to build for" },
    admins = { type = "array_string", default = [], description = "Admin usernames" },
    evalWorkerCount = { type = "number", default = 8, description = "Number of evaluation workers" },
    evalMaxMemorySize = { type = "number", default = 4096, description = "Max memory for eval workers (MB)" },
    outputsPath = { type = "string", default = "/var/www/buildbot/nix-outputs/", description = "Path for build outputs" },
    ntfyUrl = { type = "string", default = "", description = "ntfy notification URL" },
    workerName = { type = "string", description = "Worker machine name" },
    workerCores = { type = "number", default = 16, description = "Worker CPU cores" },
    github = { type = "record", default = {}, description = "GitHub app configuration" },
    effectsSecrets = { type = "record", default = {}, description = "Effects secrets per repo" },
    postBuildSteps = { type = "array", default = [], description = "Extra build steps after nix build" },
  },
  worker = {
    workers = { type = "number", default = 16, description = "Number of parallel workers" },
  },
}
