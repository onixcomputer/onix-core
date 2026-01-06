{ lib, ... }:
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
}
