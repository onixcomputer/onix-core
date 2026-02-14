{ config, ... }:
{
  services.pueue = {
    enable = true;
    settings = {
      daemon = {
        default_parallel_tasks = config.build.pueue.parallelTasks;
      };
    };
  };
}
