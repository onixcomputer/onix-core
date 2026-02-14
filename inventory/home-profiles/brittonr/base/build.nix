{ lib, ... }:
{
  options.build = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      pueue.parallelTasks = 4;
    };
    description = "Build tool parallelism settings";
  };
}
