_: {
  networking = {
    hostName = "claudia";
  };

  time.timeZone = "America/New_York";

  services.nginx = {
    enable = true;
    streamConfig = ''
      # Minecraft dj2
      server {
        listen 25565;
        proxy_pass 100.99.42.67:25565;
      }
      server {
        listen 24454 udp;
        proxy_pass 100.99.42.67:24454;
      }

      # Minecraft ad
      server {
        listen 25566;
        proxy_pass 100.99.42.67:25566;
      }
      server {
        listen 24455 udp;
        proxy_pass 100.99.42.67:24455;
      }

      # Minecraft atf10
      server {
        listen 25567;
        proxy_pass 100.99.42.67:25567;
      }
      server {
        listen 24456 udp;
        proxy_pass 100.99.42.67:24456;
      }
    '';
  };

  networking.firewall.allowedTCPPorts = [
    25565
    25566
    25567
  ];
  networking.firewall.allowedUDPPorts = [
    24454
    24455
    24456
  ];
}
