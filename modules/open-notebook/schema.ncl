{
  server = {
    stateDir = { type = "string", default = "/var/lib/open-notebook", description = "Persistent state directory for Open Notebook and SurrealDB" },
    openNotebookImage = { type = "string", default = "lfnovo/open_notebook:v1-latest", description = "OCI image for Open Notebook" },
    surrealdbImage = { type = "string", default = "surrealdb/surrealdb:v2", description = "OCI image for SurrealDB" },
    credentials = { type = "array", default = [], description = "Credential bootstrap definitions. Each entry may include: { name, provider, modalities = [\"language\"], apiKey?, baseUrl?, endpoint?, apiVersion?, endpointLlm?, endpointEmbedding?, endpointStt?, endpointTts?, project?, location?, credentialsPath?, models = [{ name, modelType }] }" },
    defaultModels = { type = "record", default = {}, description = "Default model slot assignments mapping slot name to model name" },
    installLauncher = { type = "bool", default = true, description = "Install the local open-notebook launcher command" },
  },
}
