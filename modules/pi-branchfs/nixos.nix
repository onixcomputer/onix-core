_: {
  # Install only on the two hosts that import this module.
  home-manager.users.brittonr.home.file = {
    ".pi/agent/extensions/branchfs".source = ./extension;
    ".pi/agent/skills/branchfs-workspaces/SKILL.md".source = ./skill/SKILL.md;
  };
}
