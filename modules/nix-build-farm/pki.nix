{
  config,
  lib,
  pkgs,
  instanceName,
  role,
  commonName,
  owner,
  dnsNames,
  ipAddresses ? [ ],
  serverAuth ? false,
  restartUnits,
}:
let
  caName = "${instanceName}-ca";
  leafName = "${instanceName}-${role}";
  caDays = 1825;
  leafDays = 365;
  usage = if serverAuth then "serverAuth,clientAuth" else "clientAuth";
  sans = lib.concatStringsSep "," (
    map (name: "DNS:${name}") (lib.unique dnsNames)
    ++ map (address: "IP:${address}") (lib.unique ipAddresses)
  );
  files = config.clan.core.vars.generators.${leafName}.files;
  runtimeFile = {
    secret = true;
    deploy = true;
    inherit owner restartUnits;
    group = owner;
    mode = "0400";
  };
in
assert lib.assertMsg (
  builtins.match "[A-Za-z0-9][A-Za-z0-9-]*" commonName != null
) "nix-build-farm: certificate CN must be an exact machine principal";
assert lib.assertMsg (lib.all (name: builtins.match "[A-Za-z0-9][A-Za-z0-9.-]*" name != null)
  dnsNames
) "nix-build-farm: certificate DNS names must not contain wildcards or configuration delimiters";
assert lib.assertMsg (lib.all (
  address: builtins.match "[0-9A-Fa-f:.]+" address != null
) ipAddresses) "nix-build-farm: certificate IP addresses must be IP literals";
{
  tls = {
    certFile = files.cert.path;
    keyFile = files.key.path;
    caFile = files.ca-cert.path;
  };

  generators = {
    ${caName} = {
      share = true;
      validation = {
        version = 1;
        days = caDays;
        keyBits = 4096;
      };
      files = {
        key = {
          secret = true;
          deploy = false;
        };
        ca-cert = {
          secret = false;
          deploy = false;
        };
      };
      runtimeInputs = [ pkgs.openssl ];
      script = ''
        umask 077
        openssl req -x509 -newkey rsa:4096 -noenc -sha256 \
          -days ${toString caDays} \
          -subj ${lib.escapeShellArg "/CN=${instanceName}-ca"} \
          -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
          -addext 'keyUsage=critical,keyCertSign,cRLSign' \
          -addext 'subjectKeyIdentifier=hash' \
          -keyout "$out/key" -out "$out/ca-cert"
      '';
    };

    ${leafName} = {
      share = false;
      dependencies = [ caName ];
      validation = {
        version = 1;
        days = leafDays;
        keyBits = 3072;
        inherit commonName sans usage;
      };
      # The public CA remains reviewable in vars/shared. This copy and the
      # leaf certificate are encrypted only to get stable runtime paths and
      # atomic credential rotation alongside the private key, not secrecy.
      files = {
        key = runtimeFile;
        cert = runtimeFile;
        ca-cert = runtimeFile;
      };
      runtimeInputs = [ pkgs.openssl ];
      script = ''
        umask 077
        ca="$in"/${lib.escapeShellArg caName}
        openssl x509 -checkend ${toString (leafDays * 86400)} -noout -in "$ca/ca-cert"
        openssl req -new -newkey rsa:3072 -noenc -sha256 \
          -subj ${lib.escapeShellArg "/CN=${commonName}"} \
          -keyout "$out/key" -out leaf.csr
        cat > leaf.ext <<'EOF'
        basicConstraints=critical,CA:FALSE
        keyUsage=critical,digitalSignature,keyEncipherment
        extendedKeyUsage=${usage}
        subjectKeyIdentifier=hash
        authorityKeyIdentifier=keyid,issuer
        subjectAltName=${sans}
        EOF
        openssl x509 -req -sha256 -days ${toString leafDays} \
          -in leaf.csr -CA "$ca/ca-cert" -CAkey "$ca/key" \
          -set_serial "0x$(openssl rand -hex 16)" \
          -extfile leaf.ext -out "$out/cert"
        openssl verify -CAfile "$ca/ca-cert" -purpose sslclient "$out/cert"
        ${lib.optionalString serverAuth ''
          openssl verify -CAfile "$ca/ca-cert" -purpose sslserver "$out/cert"
        ''}
        cp "$ca/ca-cert" "$out/ca-cert"
      '';
    };
  };
}
