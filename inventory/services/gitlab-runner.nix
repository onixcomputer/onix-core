_: {
  instances = {

    "onix-runners" = {
      module.name = "gitlab-runner";
      module.input = "self";
      roles.default = {
        machines.leviathan = { };
        settings = {
          runners = {
            standard-1 = {
              description = "Gitlab Docker Runner";
              executor = "docker";
              limit = 4;
              dockerImage = "alpine";
              dockerVolumes = [
                "/nix/store:/nix/store:ro"
                "/nix/var/nix/db:/nix/var/nix/db:ro"
                "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
                "/run/secrets/vars/gitlab-runner-ssh-ao-runners:/root/.ssh:ro"
              ];
              dockerDisableCache = true;
              environmentVariables = {
                ENV = "/etc/profile";
                USER = "root";
                NIX_REMOTE = "daemon";
                PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
                NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
                GIT_SSH_COMMAND = "ssh -i /root/.ssh/ssh-key -o StrictHostKeyChecking=accept-new";
              };
              preBuildScript = ''
                mkdir -p -m 0755 /nix/var/log/nix/drvs
                mkdir -p -m 0755 /nix/var/nix/gcroots
                mkdir -p -m 0755 /nix/var/nix/profiles
                mkdir -p -m 0755 /nix/var/nix/temproots
                mkdir -p -m 0755 /nix/var/nix/userpool
                mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
                mkdir -p -m 1777 /nix/var/nix/profiles/per-user
                mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
                mkdir -p -m 0700 "$HOME/.nix-defexpr"

                . /nix/store/wylax5zjg384ar002fbhbysi6cy0636b-nix-2.28.5/etc/profile.d/nix-daemon.sh

                mkdir -p /etc/nix
                echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

                /nix/store/wylax5zjg384ar002fbhbysi6cy0636b-nix-2.28.5/bin/nix-env -i \
                  /nix/store/wylax5zjg384ar002fbhbysi6cy0636b-nix-2.28.5 \
                  /nix/store/62ng4hr8akz1lmlf2g90hn2aypy8l9w6-nss-cacert-3.114 \
                  /nix/store/zhv8ib8y1zfi76afddfnp8fmm562bgaa-git-2.50.1 \
                  /nix/store/c9k1j0y8p3wx2yd48zrmb7r4il3c0h2z-openssh-10.0p2 \
                  /nix/store/zjl3cfsqvwiz2g943sm15n1gghv793m3-jq-1.8.1-bin \
                  /nix/store/xbp2j3z0lhizr5vvzff4dgdcxgs8i2w7-coreutils-9.7 \
                  /nix/store/7ca5mmsxiydw0424pij9b64pl6xjdjzq-nix-prefetch-git \
                  /nix/store/shhsic13sis060hqwyg80zbb56n3hxmf-prefetch-npm-deps-0.1.0

                export SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
                export NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt

                /nix/store/wylax5zjg384ar002fbhbysi6cy0636b-nix-2.28.5/bin/nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs || true
                /nix/store/wylax5zjg384ar002fbhbysi6cy0636b-nix-2.28.5/bin/nix-channel --update nixpkgs || true
              '';
            };

            deploy-1 = {
              description = "Deploy Runner";
              executor = "shell";
              limit = 1;
              environmentVariables = {
                GIT_SSH_COMMAND = "ssh -i /run/secrets/vars/gitlab-runner-ssh-ao-runners/ssh-key -o StrictHostKeyChecking=accept-new";
                NIX_REMOTE = "daemon";
              };
            };

          };
        };
      };
    };

  };
}
