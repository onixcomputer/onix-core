# Clan instance homepage-dashboard (inventory/services/services.ncl): every
# machine tagged homepage-server.
{
  "homepage-dashboard" = {
    service = "homepage-dashboard",
    roles.server = {
      tags = ["homepage-server"],
      settings = {
        listen_port = 8082,
        allowed_hosts = "localhost:8082,home.blr.dev",
        settings = {
          title = "Onix Services",
          theme = "dark",
          color = "slate",
          background = {
            image = "",
            blur = "sm",
            saturate = 50,
            brightness = 50,
            opacity = 50,
          },
        },
        widgets = [
          {
            search = {
              provider = "duckduckgo",
              target = "_blank",
            },
          },
          {
            datetime = {
              text_size = "lg",
              format = {
                dateStyle = "long",
                timeStyle = "short",
                hour12 = false,
              },
            },
          },
        ],
      },
    },
  },
}
