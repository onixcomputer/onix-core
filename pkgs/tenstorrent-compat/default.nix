# Keep the dedicated package authority and runtime pins; repair its consumers
# for the TT-Metal SDK already selected by that authority.
{ inputs, pkgs }:
let
  upstream = inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};
  patchRwkv =
    package:
    package.overrideAttrs (previous: {
      patches = (previous.patches or [ ]) ++ [ ./rwkv-metal-077.patch ];
    });
  diagnosticMetal = upstream.tt-metal.overrideAttrs (previous: {
    pname = "${previous.pname}-fetch-queue-diagnostics";
    patches = (previous.patches or [ ]) ++ [ ./fetch-queue-diagnostics.patch ];
  });
  runtime = patchRwkv upstream.rwkv7-p150x2-runtime;
  diagnosticRuntime = patchRwkv (
    upstream.rwkv7-p150x2-fetch-queue-diagnostic-runtime.override {
      tt-metal = diagnosticMetal;
    }
  );
in
upstream
// {
  llama-cpp-metalium = upstream.llama-cpp-metalium.overrideAttrs (previous: {
    # Upstream's strict substitutions must run before the SDK migration.
    postPatch = (previous.postPatch or "") + ''
      patch -p1 < ${./llama-metal-077.patch}
    '';
  });
  rwkv7-p150x2-runtime = runtime;
  rwkv7-p150x2-fetch-queue-diagnostic-runtime = diagnosticRuntime;
  rwkv7-p150x2-evidence = upstream.rwkv7-p150x2-evidence.override {
    deviceRuntime = runtime;
    diagnosticDeviceRuntime = diagnosticRuntime;
  };
}
