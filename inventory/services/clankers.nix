_: {
  instances = {

    # Clankers daemon — persistent agent sessions over iroh QUIC.
    # Runs on dev machines so agents are reachable remotely.
    "clankers-daemon" = {
      module.name = "clankers";
      module.input = "self";
      roles.daemon = {
        tags."dev" = { };
        settings = {
          user = "brittonr";
          allowAll = false;
          heartbeat = 30;
        };
      };
    };

    # Clanker-router — multi-provider LLM proxy.
    # Runs on the desktop (has API keys and GPU for local models).
    "clanker-router" = {
      module.name = "clankers";
      module.input = "self";
      roles.router.machines.britton-desktop.settings = {
        user = "brittonr";
        listenAddr = "0.0.0.0";
        listenPort = 4000;
        enableIroh = true;
      };
    };

  };
}
