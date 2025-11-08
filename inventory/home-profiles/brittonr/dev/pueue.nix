_: {
  services.pueue = {
    enable = true;
    settings = {
      daemon = {
        default_parallel_tasks = 4;
      };
    };
  };
}
