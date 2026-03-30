{
  server = {
    port = { type = "port", default = 8888, description = "HTTP port for the static server" },
    directory = { type = "string", default = "/var/www/static", description = "Directory to serve files from" },
    createTestPage = { type = "bool", default = true, description = "Create a default test page" },
    testPageTitle = { type = "string", default = "Static Server Test", description = "Title for the test page" },
    testPageContent = { type = "string", default = "", description = "Extra HTML content for the test page" },
    serviceSuffix = { type = "string", default = "", description = "Suffix for unique service names" },
    isPublic = { type = "bool", default = false, description = "Whether this service is publicly accessible" },
    domain = { type = "string", default = "", description = "Domain name if available" },
    subdomain = { type = "string", default = "", description = "Subdomain for this service" },
  },
}
