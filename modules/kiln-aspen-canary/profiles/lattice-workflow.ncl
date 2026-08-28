# One reviewed local shell workflow for the private Kiln-on-Aspen canary.
let Port = { id | Number, label | String, type_tag | String } in
let Node = {
  id | Number,
  label | String,
  x | Number,
  y | Number,
  input_ports | Array Port,
  output_ports | Array Port,
}
in
let Edge = { source | Number, target | Number } in
let EnvVar = { key | String, value | String } in
let SecretEnvVar = {
  name | String,
  provider | String,
  key | String,
  field | Array String,
}
in
let NodeConfig = {
  node_id | Number,
  kind | String,
  command | String,
  cwd | Array String,
  env | Array EnvVar,
  secret_env | Array SecretEnvVar,
  http_method | String,
  url | String,
  headers | Array EnvVar,
  body | Array String,
  file_operation | String,
  file_path | String,
  file_content | Array String,
  overwrite | Bool,
  allowed_roots | Array String,
  timeout_secs | Number,
  pipe_stdin | Bool,
}
in
let Meta = {
  name | String,
  description | String,
  created | String,
  modified | String,
}
in
let Workflow = {
  meta | Meta,
  nodes | Array Node,
  edges | Array Edge,
  configs | Array NodeConfig,
}
in
let workflow_node_id = 0 in
let input_port_id = 10 in
let stdout_port_id = 11 in
let stderr_port_id = 12 in
let exit_port_id = 13 in
let timeout_seconds = 30 in
({
  meta = {
    name = "kiln-aspen-canary",
    description = "Verify one source-bound Kiln workflow effect",
    created = "2026-08-27T00:00:00Z",
    modified = "2026-08-27T00:00:00Z",
  },
  nodes = [
    {
      id = workflow_node_id,
      label = "build",
      x = 0,
      y = 0,
      input_ports = [{ id = input_port_id, label = "stdin", type_tag = "string" }],
      output_ports = [
        { id = stdout_port_id, label = "stdout", type_tag = "string" },
        { id = stderr_port_id, label = "stderr", type_tag = "string" },
        { id = exit_port_id, label = "exit", type_tag = "exitcode" },
      ],
    }
  ],
  edges = [],
  configs = [
    {
      node_id = workflow_node_id,
      kind = "shell",
      command = "test -n \"$LATTICE_SOURCE_PROVIDER\" && test -n \"$LATTICE_SOURCE_REPOSITORY\" && test -n \"$LATTICE_SOURCE_REVISION\" && printf 'kiln-aspen-canary\\n'",
      cwd = [],
      env = [],
      secret_env = [],
      http_method = "",
      url = "",
      headers = [],
      body = [],
      file_operation = "",
      file_path = "",
      file_content = [],
      overwrite = false,
      allowed_roots = [],
      timeout_secs = timeout_seconds,
      pipe_stdin = false,
    }
  ],
}
) | Workflow
