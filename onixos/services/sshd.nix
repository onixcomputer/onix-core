# sshd.ncl reads the public host key, certificate and CA key that
# openssh-keys.ncl declares; a module never sees its own public artifacts.
_: {
  inputs = [ "openssh-keys" ];
}
