{
  server = {
    stateDir = { type = "string", default = "/var/lib/open-notebook", description = "Persistent state directory for Open Notebook and SurrealDB" },
    openNotebookImage = { type = "string", default = "lfnovo/open_notebook:v1-latest@sha256:4ebaffeeab1872c14f3ffbb9e22a259c13f7576122a97e770c38b2fae2628a1b", description = "OCI image for Open Notebook" },
    surrealdbImage = { type = "string", default = "surrealdb/surrealdb:v2@sha256:d653f6c8a89e81f865ee31cd2f587c50f50ace922175e04150b1e385d2f86011", description = "OCI image for SurrealDB" },
    credentials = { type = "array", default = [], description = "Credential bootstrap definitions. Each entry may include: { name, provider, modalities = [\"language\"], apiKey?, baseUrl?, endpoint?, apiVersion?, endpointLlm?, endpointEmbedding?, endpointStt?, endpointTts?, project?, location?, credentialsPath?, models = [{ name, modelType }] }" },
    defaultModels = { type = "record", default = {}, description = "Default model slot assignments. Values may be a model name string or a record like { name, credential?, provider? } to disambiguate matches across multiple credentials." },
    installLauncher = { type = "bool", default = true, description = "Install the local open-notebook launcher command" },
  },
}
