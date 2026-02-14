{ lib, ... }:
{
  options.timing = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      # Process delays (seconds, as strings for shell scripts)
      process = {
        veryShort = "0.2";
        short = "0.5";
        daemonStart = "1";
        wifiScan = "2";
      };
      # Notification display durations (milliseconds)
      notification = {
        gesture = 400;
        quick = 1000;
        standard = 2000;
        long = 10000;
      };
    };
    description = "Process timing delays and notification durations";
  };
}
