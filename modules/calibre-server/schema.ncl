{
  server = {
    libraries = { type = "array_string", default = ["/srv/calibre/library"], description = "List of Calibre library paths" },
    host = { type = "string", default = "0.0.0.0", description = "Address to bind to" },
    port = { type = "port", default = 8080, description = "Server port" },
    user = { type = "string", default = "calibre-server", description = "System user" },
    group = { type = "string", default = "calibre-server", description = "System group" },
  },
}
