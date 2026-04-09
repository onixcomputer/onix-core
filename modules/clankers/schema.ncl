{
  daemon = {
    model = { type = "string", default = "claude-opus-4-6", description = "Default LLM model for agent sessions" },
    allowAll = { type = "bool", default = false, description = "Skip token/ACL checks (development mode)" },
    heartbeat = { type = "number", default = 30, description = "Heartbeat interval in seconds (0 to disable)" },
    apiBase = { type = "nullable_string", default = null, description = "API base URL for the LLM proxy" },
    extraArgs = { type = "array_string", default = [], description = "Extra arguments passed to clankers daemon start" },
    schedules = { type = "array", default = [], description = "Declarative schedules seeded on daemon start. Each entry: {name, kind (interval|cron), interval (secs), cron (pattern), prompt, maxFires?}" },
    emailAuth = { type = "bool", default = false, description = "Enable email plugin auth vars (Fastmail JMAP token, from address, allowed recipients)" },
    emailFrom = { type = "string", default = "", description = "Default sender address for the clankers-email plugin" },
    emailAllowedRecipients = { type = "string", default = "", description = "Comma-separated allowed recipient emails or @domain patterns" },
  },
  router = {
    listenAddr = { type = "string", default = "0.0.0.0", description = "Address to bind the HTTP proxy" },
    listenPort = { type = "port", default = 4000, description = "Port for the OpenAI-compatible HTTP proxy" },
    useOAuth = { type = "bool", default = false, description = "Use OAuth credentials instead of API keys" },
    oauthAccounts = { type = "array_string", default = ["default"], description = "OAuth account names to prompt for (each gets access + refresh token)" },
    oauthActiveAccount = { type = "string", default = "default", description = "Active OAuth account name" },
    proxyKeys = { type = "array_string", default = [], description = "API keys allowed to access the proxy" },
    extraArgs = { type = "array_string", default = [], description = "Extra arguments passed to clanker-router serve" },
    localProviders = { type = "array", default = [], description = "Extra OpenAI-compatible providers to register. Each entry: {name, apiBase, models = [\"model-id\", ...]}" },
  },
}
