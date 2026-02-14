{ lib, ... }:
{
  options.notifications = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      timeout = 5000;
      maxVisible = 5;
      width = 300;
      height = 100;
      padding = 15;
      margin = 10;
      position = "top-right";
      gap = 10;
      maxHistory = 20;
      urgency = {
        low = 3;
        normal = 5;
        critical = 10;
      };
    };
    description = "Notification daemon settings";
  };
}
