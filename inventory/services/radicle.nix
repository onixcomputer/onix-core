_: {
  instances = {
    # Britton's Radicle setup
    "radicle-britton" = {
      module.name = "radicle";
      module.input = "self";

      # Seed node on britton-desktop
      roles.seed = {
        tags."radicle-seed" = { };
        settings = {
          # External address for the seed node (update with your actual domain/IP)
          # If using Tailscale, you can use the Tailscale hostname
          externalAddress = "britton-desktop:8776";

          # Permissive seeding - will replicate all repositories it encounters
          seedingPolicy = "permissive";

          # Node configuration
          node = {
            listenAddress = "0.0.0.0";
            listenPort = 8776;
            openFirewall = true;
          };

          # Enable HTTP gateway for web access
          httpd = {
            enable = true;
            listenAddress = "0.0.0.0";
            listenPort = 8777;
          };

          # Initialize with specific repositories
          initialRepositories = [
            # Uncomment to pre-seed with Radicle's own repos
            "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5" # heartwood (Radicle protocol)
            "rad:z3trNYnLWS11cJWC6BbxDs5niGo82" # rips (Radicle Improvement Proposals)
            "rad:z3TajuiHW5xmGYdZbHPW7mPLjhkQC" # radicle-interface
          ];

          # Optional: Pin specific repositories to feature in the web UI
          settings = {
            web.pinned.repositories = [
              # Add repository IDs here once you have some
              # "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5"  # heartwood
            ];

            # Connect to well-known seed nodes to discover more repos
            node.connect = [
              # "seed.radicle.xyz:8776"     # Official Radicle seed
              # "seed.radicle.garden:8776"  # Community seed
            ];
          };
        };
      };

      # Developer node on britton-fw (laptop)
      roles.node = {
        tags."radicle-node" = { };
        settings = {
          # Selective seeding - only replicate repos you explicitly choose
          seedingPolicy = "selective";

          # Enable HTTP gateway for local browsing
          enableHttpd = true;

          # Node configuration - local only by default
          node = {
            listenAddress = "127.0.0.1";
            listenPort = 8776;
            openFirewall = false;
          };

          # HTTP gateway configuration
          httpd = {
            listenAddress = "127.0.0.1";
            listenPort = 8777;
          };

          # Connect to seed nodes
          settings = {
            node = {
              connect = [
                # Connect to britton-desktop seed node (update node-id after deployment)
                # Get the node ID by running: rad self --nid
                # "z6Mk...@britton-desktop:8776"

                # Optionally connect to public seeds for discovery
                # "seed.radicle.xyz:8776"
                # "seed.radicle.garden:8776"
              ];
            };
          };
        };
      };
    };
  };
}
