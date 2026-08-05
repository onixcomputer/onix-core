{ config, pkgs, ... }:
let
  # Keep `pueue status` readable with many groups: truncate tall table rows.
  maxStatusLines = 20;
  # Lines of task output available to the finish callback template.
  callbackLogLines = 10;
in
{
  services.pueue = {
    enable = true;
    settings = {
      daemon = {
        default_parallel_tasks = config.build.pueue.parallelTasks;
        callback_log_lines = callbackLogLines;
        callback = "${pkgs.libnotify}/bin/notify-send \"pueue task {{ id }}: {{ result }}\" \"group: {{ group }}\ncommand: {{ command }}\"";
      };
      client = {
        dark_mode = config.colorScheme.darkMode;
        max_status_lines = maxStatusLines;
      };
    };
  };
}
