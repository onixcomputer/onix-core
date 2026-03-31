{ inputs, ... }:
{
  imports = [ inputs.musnix.nixosModules.musnix ];

  musnix = {
    enable = true;

    # Realtime kernel disabled — causes infinite recursion with nvidia tag.
    # Re-enable once musnix handles PREEMPT_RT on 6.12+ without kernel.packages self-ref.
    kernel.realtime = false;

    # das_watchdog: kill runaway RT processes before they hang the machine.
    das_watchdog.enable = true;

    # rtcqs: CLI tool to audit the system for audio-friendliness.
    rtcqs.enable = true;
  };
}
