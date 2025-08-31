_: {
  instances = {
    "gitlab-runner-dpe-project" = {
      module.name = "gitlab-runner";
      module.input = "self";
      roles.default = {
        machines.aspen1 = { };
        settings = {
          description = "DPE Project Dedicated Runner";
          executor = "docker";
          dockerImage = "alpine";
          dockerVolumes = [
            "/nix/store:/nix/store:ro"
            "/nix/var/nix/db:/nix/var/nix/db:ro"
            "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
          ];
          dockerDisableCache = true;
          environmentVariables = {
            ENV = "/etc/profile";
            USER = "root";
            NIX_REMOTE = "daemon";
            PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
            NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
          };
        };
      };
    };

  };
}
