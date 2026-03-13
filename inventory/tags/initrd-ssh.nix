# Initrd SSH — remote access to the initrd for debugging or disk unlock.
# SSH on port 2222 with clan vars-managed host keys.
# Assign this tag to machines that need remote initrd access.
_: {
  imports = [ ./common/initrd-ssh.nix ];
}
