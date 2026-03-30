{
  server = {
    port = { type = "port", default = 5000, description = "HTTP port for the binary cache" },
    workers = { type = "number", default = 4, description = "Number of worker threads" },
    maxConnectionRate = { type = "number", default = 256, description = "Maximum connection rate" },
    priority = { type = "number", default = 30, description = "Binary cache priority (lower = preferred)" },
  },
}
