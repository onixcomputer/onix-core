# Re-export the dedicated Tenstorrent package authority through onix-core.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  supportedSystem = "x86_64-linux";
  system = pkgs.stdenv.hostPlatform.system;
  isSupportedSystem = system == supportedSystem;
  tenstorrent = self.inputs.tenstorrent-nix;
  # r[impl onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation]
  # r[verify onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation]
  packageNames = [
    "rwkv-lab"
    "rwkv-layer-harness"
    "rwkv-ttwkv7-boundary-device"
    "rwkv-ttwkv7-persistent-device"
    "rwkv7-p150x2-evidence"
    "rwkv7-p150x2-runtime"
    "tt-vibethinker-bench"
    "ttsim"
    "ttwkv7"
    "ttwkv7-owner-control"
  ];
  checkNames = [
    "migration-boundary"
    "rwkv-layer-framework-parity"
    "rwkv-ttwkv7-boundary-device"
    "rwkv-ttwkv7-decode-reader"
    "rwkv-ttwkv7-dispatch-abi"
    "rwkv-ttwkv7-host-layout"
    "rwkv-ttwkv7-model-dispatch"
    "rwkv-ttwkv7-observed-layer"
    "rwkv-ttwkv7-observed-model-carry"
    "rwkv-ttwkv7-observed-state-carry"
    "rwkv-ttwkv7-persistent-device"
    "rwkv-ttwkv7-persistent-device-4-evidence"
    "rwkv-ttwkv7-persistent-device-4-runbook"
    "rwkv-ttwkv7-persistent-dispatch-transport"
    "rwkv-ttwkv7-persistent-model-dispatch"
    "rwkv-ttwkv7-persistent-partial-diagnostic"
    "rwkv-ttwkv7-persistent-physical-core"
    "rwkv-ttwkv7-persistent-physical-process-shell"
    "tt-vibethinker-bench-package"
    "ttsim-package"
    "ttwkv7-architectures"
    "ttwkv7-owner-control-package"
  ];
  selectRequired =
    kind: available: names:
    lib.genAttrs names (
      name:
      assert lib.assertMsg (builtins.hasAttr name available)
        "tenstorrent.nix is missing required ${kind} output ${name}";
      available.${name}
    );
in
{
  # The package re-exports are the local integration anchors for external
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.session_receipts]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_dispatch_abi]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_device_4_evidence]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_dispatch]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_partial_diagnostic]
  # r[impl onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.data_movement_diagnostic]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.owner_control]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.package]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.production_probe_wrapper]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.single_device_topology]
  # r[impl onix.tenstorrent.native_runtime.dedicated_repository]
  packages = lib.optionalAttrs isSupportedSystem (
    selectRequired "package" tenstorrent.packages.${system} packageNames
  );

  # The dedicated checks are the local verification anchors for external
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.greedy_token]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.session_receipts]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_dispatch_abi]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_layer_replay]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_device_4_evidence]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_dispatch]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_partial_diagnostic]
  # r[verify onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.data_movement_diagnostic]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.owner_control]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.package]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.production_probe_wrapper]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment]
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.single_device_topology]
  # r[verify onix.tenstorrent.native_runtime.dedicated_repository]
  checks = lib.optionalAttrs isSupportedSystem (
    selectRequired "check" tenstorrent.checks.${system} checkNames
  );
}
