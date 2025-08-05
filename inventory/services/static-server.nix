_: {
  instances = {
    # Test instance for britton-fw
    "static-server-test" = {
      module.name = "static-server";
      module.input = "self";
      roles.server = {
        tags."static-test" = { };
        settings = {
          port = 8888;
          directory = "/var/www/test";
          createTestPage = true;
          testPageTitle = "Tailscale-Traefik Public Mode Test";
          serviceSuffix = "test";
          isPublic = true;
          domain = "blr.dev";
          subdomain = "test";
          testPageContent = "";
        };
      };
    };

    # Demo instance for britton-fw (private access only)
    "static-server-demo" = {
      module.name = "static-server";
      module.input = "self";
      roles.server = {
        tags."static-demo" = { };
        settings = {
          port = 8889;
          directory = "/var/www/demo";
          createTestPage = true;
          testPageTitle = "Private Demo Server (Tailscale Only)";
          serviceSuffix = "demo";
          isPublic = false;
          domain = "blr.dev";
          subdomain = "demo";
          testPageContent = "";
        };
      };
    };
  };
}
