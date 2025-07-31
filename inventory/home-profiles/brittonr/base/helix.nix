{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "everblush";
      editor = {
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
      };
      keys.normal = {
        space = {
          space = "file_picker";
          w = ":w";
          q = ":q";
        };
      };
    };
  };
}
