{
  inputs,
  lib,
  pkgs,
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  tenstorrentPackagesBase = inputs.tenstorrent-nix.packages.${hostSystem};
  ttFlashPyYamlPinnedRequirement = "pyyaml == 6.0.1";
  ttFlashPyYamlNixRequirement = "pyyaml >= 6.0.1";
  ttFlashTabulatePinnedRequirement = "tabulate == 0.9.0";
  ttFlashTabulateNixRequirement = "tabulate >= 0.9.0";
  tenstorrentPackageRenames = {
    burnin = "tt-burnin";
    flash = "tt-flash";
    smi = "tt-smi";
    system-tools = "tt-system-tools";
    topology = "tt-topology";
  };
  selectTenstorrentPackageName =
    fallbackName: preferredName:
    if builtins.hasAttr preferredName tenstorrentPackagesBase then preferredName else fallbackName;
  mkTenstorrentPackageAlias =
    fallbackName: preferredName:
    let
      packageName = selectTenstorrentPackageName fallbackName preferredName;
    in
    assert lib.assertMsg (builtins.hasAttr packageName tenstorrentPackagesBase)
      "tenstorrent.nix package '${fallbackName}' was not found as '${preferredName}' or '${fallbackName}'";
    tenstorrentPackagesBase.${packageName};
  tenstorrentPackageAliases = lib.mapAttrs mkTenstorrentPackageAlias tenstorrentPackageRenames;
  # Several Tenstorrent Python CLIs still depend on modules removed from the
  # default Python 3.14 package set.
  tenstorrentPythonPackages =
    (import inputs.nixpkgs {
      system = hostSystem;
      overlays = [ inputs.tenstorrent-nix.overlays.default ];
    }).python313Packages;
  tenstorrentBurnin = tenstorrentPackageAliases.burnin.override {
    python3Packages = tenstorrentPythonPackages;
  };
  tenstorrentTopology =
    (tenstorrentPackageAliases.topology.override {
      python3Packages = tenstorrentPythonPackages;
    }).overrideAttrs
      (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace tt_topology/tt_topology.py \
            --replace-fail "import pkg_resources" "from importlib.metadata import version as distribution_version" \
            --replace-fail 'pkg_resources.get_distribution("tt_topology").version' 'distribution_version("tt-topology")'
        '';
      });
  tenstorrentFlash = tenstorrentPythonPackages.tt-flash.overrideAttrs (oldAttrs: {
    # Older tenstorrent.nix revisions carried a context-sensitive patch in this
    # area. Prefer Nix-controlled runtime versions, but skip the substitution
    # when newer upstream metadata has already relaxed the pins.
    patches = [ ];
    postPatch = (oldAttrs.postPatch or "") + ''
      if grep -Fq ${lib.escapeShellArg ttFlashPyYamlPinnedRequirement} pyproject.toml; then
        substituteInPlace pyproject.toml \
          --replace-fail "${ttFlashPyYamlPinnedRequirement}" "${ttFlashPyYamlNixRequirement}"
      fi
      if grep -Fq ${lib.escapeShellArg ttFlashTabulatePinnedRequirement} pyproject.toml; then
        substituteInPlace pyproject.toml \
          --replace-fail "${ttFlashTabulatePinnedRequirement}" "${ttFlashTabulateNixRequirement}"
      fi
    '';
  });
  tenstorrentPackageSet =
    tenstorrentPackagesBase
    // tenstorrentPackageAliases
    // {
      burnin = tenstorrentBurnin;
      flash = tenstorrentFlash;
      topology = tenstorrentTopology;
    };
  # r[impl onix.tenstorrent.native_runtime.packages]
  metal = mkTenstorrentPackageAlias "tt-metal" "tt-metal";
  llamaCppMetalium = mkTenstorrentPackageAlias "llama-cpp-metalium" "llama-cpp-metalium";
  # r[impl onix.tenstorrent.native_runtime.ttwkv7.host]
  ttwkv7 = pkgs.callPackage ../../../pkgs/ttwkv7 {
    inherit (tenstorrentPackagesBase) enchantum tt-logger;
    tt-metal = metal;
  };
  # r[impl onix.tenstorrent.native_runtime.p150x2_mesh]
  metaliumRoot = "${metal}/libexec/tt-metalium";
  meshDescriptorFilename = "p150_x2_mesh_graph_descriptor.textproto";
  meshDescriptorPath = "${metaliumRoot}/tt_metal/fabric/mesh_graph_descriptors/${meshDescriptorFilename}";
  missingMeshDescriptorPath = "${metaliumRoot}/tt_metal/fabric/mesh_graph_descriptors/missing_mesh_graph_descriptor.textproto";
  ttwkv7KernelRoot = "${ttwkv7}/share/ttwkv7/kernels";
  ttwkv7KernelSourceNames = [
    "wkv7_chunked_compute.cpp"
    "wkv7_decodeL_compute.cpp"
    "wkv7_decodeL_reader.cpp"
    "wkv7_reader.cpp"
    "wkv7_writer.cpp"
    "ttwkv7_data_movement_capture_writer.cpp"
    "ttwkv7_data_movement_capture_source_reader.cpp"
    "ttwkv7_data_movement_source_reader.cpp"
  ];
  missingTtwkv7KernelPath = "${ttwkv7KernelRoot}/missing-wkv7-kernel.cpp";
  mkTtwkv7KernelLayoutCheck =
    kernelSourceName: "test -f ${lib.escapeShellArg "${ttwkv7KernelRoot}/${kernelSourceName}"}";
  ttwkv7KernelLayoutChecks =
    lib.concatMapStringsSep "\n" mkTtwkv7KernelLayoutCheck
      ttwkv7KernelSourceNames;
  # Positive and negative layout cases for
  # r[verify onix.tenstorrent.native_runtime.p150x2_mesh],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.host],
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic], and
  # r[verify onix.tenstorrent.native_runtime.ttwkv7.reader_diagnostic_loop].
  nativeRuntimeLayoutCheck = pkgs.runCommand "tenstorrent-native-runtime-layout" { } ''
    test -d ${lib.escapeShellArg metaliumRoot}
    test -f ${lib.escapeShellArg meshDescriptorPath}
    test -x ${lib.escapeShellArg "${llamaCppMetalium}/bin/llama-server"}
    test -x ${lib.escapeShellArg "${ttwkv7}/bin/wkv7"}
    test -x ${lib.escapeShellArg "${ttwkv7}/bin/wkv7-diagnose"}
    test -x ${lib.escapeShellArg "${ttwkv7}/bin/wkv7-data-movement"}
    ${ttwkv7KernelLayoutChecks}
    test ! -e ${lib.escapeShellArg missingMeshDescriptorPath}
    test ! -e ${lib.escapeShellArg missingTtwkv7KernelPath}
    touch "$out"
  '';
in
{
  inherit
    llamaCppMetalium
    metal
    metaliumRoot
    meshDescriptorFilename
    meshDescriptorPath
    nativeRuntimeLayoutCheck
    ttwkv7
    ;
  tenstorrentPackages = tenstorrentPackageSet;
}
