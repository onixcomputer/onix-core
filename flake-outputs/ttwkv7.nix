# Standalone ttWKV7 package, isolated so its missing upstream license does not
# relax unfree policy for the repository's general package set.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  isSupportedSystem = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  ttwkv7Pkgs = import self.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfreePredicate = package: lib.getName package == "ttwkv7";
  };
  tenstorrentPackages = self.inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};
  rwkvLab = pkgs.callPackage ../pkgs/rwkv-lab { };
  rwkvLayerHarness = pkgs.callPackage ../pkgs/rwkv-layer-harness { };
  ttwkv7 = ttwkv7Pkgs.callPackage ../pkgs/ttwkv7 {
    inherit (tenstorrentPackages) enchantum tt-logger;
    inherit (tenstorrentPackages) tt-metal;
  };
  ttwkv7OwnerControl = pkgs.callPackage ../pkgs/ttwkv7-owner-control {
    commandName = "ttwkv7-owner-control";
    ownerUnit = "docker-tt-inference-server-llama-3-1-8b-instruct-p150.service";
    devicePath = "/dev/tenstorrent/1";
  };
  rwkvTtwkv7BoundaryDevice = pkgs.callPackage ../pkgs/rwkv-ttwkv7-boundary-device {
    inherit
      rwkvLab
      rwkvLayerHarness
      ttwkv7
      ttwkv7OwnerControl
      ;
  };
  rwkvTtwkv7HostLayoutCheck = ttwkv7Pkgs.callPackage ../pkgs/ttwkv7/rwkv-host-layout-check.nix {
    inherit rwkvLayerHarness ttwkv7;
  };
  rwkvTtwkv7DecodeReaderCheck = ttwkv7Pkgs.callPackage ../pkgs/ttwkv7/rwkv-decode-reader-check.nix {
    inherit rwkvLayerHarness ttwkv7;
  };
  rwkvTtwkv7BoundaryDeviceCheck = pkgs.callPackage ../pkgs/rwkv-ttwkv7-boundary-device/check.nix {
    boundaryDevice = rwkvTtwkv7BoundaryDevice;
    inherit ttwkv7;
  };
in
{
  packages = lib.optionalAttrs isSupportedSystem {
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.session_receipts]
    rwkv-lab = rwkvLab;
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
    rwkv-layer-harness = rwkvLayerHarness;
    # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
    rwkv-ttwkv7-boundary-device = rwkvTtwkv7BoundaryDevice;
    # r[impl onix.tenstorrent.native_runtime.ttwkv7.package]
    inherit ttwkv7;
  };

  checks = lib.optionalAttrs isSupportedSystem {
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
    rwkv-layer-framework-parity = rwkvLayerHarness.passthru.frameworkParityCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
    rwkv-ttwkv7-observed-layer = rwkvLayerHarness.passthru.observedLayerReplayCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
    rwkv-ttwkv7-observed-state-carry = rwkvLayerHarness.passthru.stateCarryCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
    rwkv-ttwkv7-observed-model-carry = rwkvLayerHarness.passthru.modelCarryCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_dispatch_abi]
    rwkv-ttwkv7-dispatch-abi = rwkvLayerHarness.passthru.dispatchAbiCheck;
    # r[verify onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
    ttwkv7-architectures = ttwkv7.passthru.architectureCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout]
    rwkv-ttwkv7-host-layout = rwkvTtwkv7HostLayoutCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
    rwkv-ttwkv7-decode-reader = rwkvTtwkv7DecodeReaderCheck;
    # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
    rwkv-ttwkv7-boundary-device = rwkvTtwkv7BoundaryDeviceCheck;
  };
}
