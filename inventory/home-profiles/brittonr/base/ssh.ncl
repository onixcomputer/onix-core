# SSH matchBlocks — source of truth for SSH host config.
#
# Consumed by: ssh.nix (home-manager programs.ssh.matchBlocks)
# Validated at `ncl export` time — bad hostnames, missing identity
# files, and typos fail immediately.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/ssh.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let MatchBlock = {
  hostname | NonEmpty | optional,
  user | NonEmpty | optional,
  identityFile | NonEmpty | optional,
  identitiesOnly | Bool | optional,
  addKeysToAgent | NonEmpty | optional,
  compression | Bool | optional,
  forwardAgent | Bool | optional,
}
in

{
  defaults | { addKeysToAgent | NonEmpty, compression | Bool, forwardAgent | Bool } = {
    addKeysToAgent = "yes",
    compression = true,
    forwardAgent = true,
  },

  identityFile | NonEmpty = "~/.ssh/framework",

  hosts | { _ : MatchBlock } = {
    "github.com" = {
      hostname = "github.com",
      user = "git",
    },
    "git.clan.lol" = {
      hostname = "git.clan.lol",
      user = "gitea",
    },
    "gitlab.com" = {
      hostname = "gitlab.com",
      user = "git",
    },
    "britton-air" = {
      hostname = "britton-air.local",
      user = "brittonr",
    },
  },
}
