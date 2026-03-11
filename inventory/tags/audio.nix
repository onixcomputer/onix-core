{ lib, pkgs, ... }:
{
  # Disable PulseAudio in favor of PipeWire
  services.pulseaudio.enable = lib.mkForce false;

  # PipeWire for modern audio handling
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  # RealtimeKit for low-latency audio
  security.rtkit.enable = lib.mkDefault true;

  # pactl / pamixer for CLI volume control
  environment.systemPackages = with pkgs; [
    pulseaudio # for pactl
    pamixer
  ];

  # Mute audio before suspend — prevents loud blast when opening laptop lid
  systemd.services.audio-off = {
    description = "Mute audio before suspend";
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = "XDG_RUNTIME_DIR=/run/user/1000";
      User = "brittonr";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.pamixer}/bin/pamixer --mute";
    };
  };
}
