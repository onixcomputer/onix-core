# Verify that the module registry in services/contracts.ncl stays in
# sync with the actual module directories in modules/.
#
# Catches two kinds of drift:
#   - Module registered in contracts.ncl but no directory exists
#   - Module directory exists (and is in modules/default.nix) but not
#     registered in contracts.ncl
#
# Note: borgbackup-extras and matrix-synapse-cf are plain NixOS modules
# loaded via extraModules, not clan perInstance service definitions.
# They are intentionally absent from the registry.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  moduleLists = wasm.evalNickelFile ../inventory/services/module-lists.ncl;
  sglangDiffusionValidation = wasm.evalNickelFile ../inventory/services/fixtures/sglang-diffusion-validation.ncl;
  lemonadeRender = import ../modules/lemonade/render.nix { inherit lib; };

  lemonadeTestContextSize = 131072;
  lemonadeTestPixels = 512;
  lemonadeTestSteps = 8;
  lemonadeTestCfgScale = 0.0;
  lemonadeTestSdCppArgs = "--diffusion-fa --offload-to-cpu --vae-tiling";
  lemonadePositiveModels = {
    "Krea-2-Turbo" = {
      checkpoints = {
        main = "vantagewithai/Krea-2-Turbo-GGUF:krea2_turbo-Q4_K_M.gguf";
        text_encoder = "Comfy-Org/Krea-2:text_encoders/qwen3vl_4b_fp8_scaled.safetensors";
        vae = "Comfy-Org/Krea-2:vae/qwen_image_vae.safetensors";
      };
      recipe = lemonadeRender.sdCppRecipe;
      labels = [ "image" ];
      imageDefaults = {
        steps = lemonadeTestSteps;
        cfg_scale = lemonadeTestCfgScale;
        width = lemonadeTestPixels;
        height = lemonadeTestPixels;
      };
      recipeOptions.sdcpp_args = lemonadeTestSdCppArgs;
    };
    "Example-LLM" = {
      checkpoint = "example/llm:Q4_K_M";
      recipe = lemonadeRender.llamaCppRecipe;
    };
  };
  lemonadeNegativeModels = {
    "Broken-Krea" = {
      checkpoints.main = "vantagewithai/Krea-2-Turbo-GGUF:krea2_turbo-Q4_K_M.gguf";
      recipe = lemonadeRender.sdCppRecipe;
    };
  };
  lemonadePositiveErrors = lemonadeRender.customModelAssetErrors lemonadePositiveModels;
  lemonadeNegativeErrors = lemonadeRender.customModelAssetErrors lemonadeNegativeModels;
  lemonadePositiveUserModels = lemonadeRender.renderUserModels lemonadePositiveModels;
  lemonadePositiveRecipeOptions = lemonadeRender.renderRecipeOptions {
    customModels = lemonadePositiveModels;
    contextSize = lemonadeTestContextSize;
    backend = "rocm";
    effectiveExtraArgs = "--llama-only";
  };
  lemonadeKreaUserModel = lemonadePositiveUserModels."Krea-2-Turbo";
  lemonadeKreaRecipeOptions = lemonadePositiveRecipeOptions."user.Krea-2-Turbo";
  lemonadeLlmRecipeOptions = lemonadePositiveRecipeOptions."user.Example-LLM";
  lemonadeRequiredKreaRoles = [
    "main"
    "text_encoder"
    "vae"
  ];
  missingRenderedKreaRoles = builtins.filter (
    role: !(builtins.hasAttr role (lemonadeKreaUserModel.checkpoints or { }))
  ) lemonadeRequiredKreaRoles;
  kreaLlamaOnlyRecipeFields =
    builtins.filter (field: builtins.hasAttr field lemonadeKreaRecipeOptions)
      [
        "ctx_size"
        "llamacpp_backend"
        "llamacpp_args"
      ];
  missingLlmRecipeFields =
    builtins.filter (field: !(builtins.hasAttr field lemonadeLlmRecipeOptions))
      [
        "ctx_size"
        "llamacpp_backend"
        "llamacpp_args"
      ];
  expectedLemonadeNegativeFields = [
    "text_encoder"
    "vae"
  ];
  missingLemonadeNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) lemonadeNegativeErrors)
  ) expectedLemonadeNegativeFields;

  # Modules registered in contracts.ncl (clan perInstance services only)
  registeredModules = lib.sort lib.lessThan moduleLists.selfModules;

  # Module directories on disk that are clan perInstance services
  # (i.e., listed in modules/default.nix).
  moduleDefs = import ../modules { inherit (self) inputs; };
  diskModules = lib.sort lib.lessThan (lib.attrNames moduleDefs);

  inRegistryNoDisk = lib.subtractLists diskModules registeredModules;
  onDiskNoRegistry = lib.subtractLists registeredModules diskModules;

  # Modules missing schema.ncl files
  modulesWithoutSchema = builtins.filter (
    name: !builtins.pathExists (self + "/modules/${name}/schema.ncl")
  ) diskModules;

  sglangPositiveErrors = sglangDiffusionValidation.positive;
  sglangNegativeErrors = sglangDiffusionValidation.negative;
  expectedSglangNegativeFields = [
    "port"
    "numGpus"
    "gpuPassthrough"
    "environmentFiles"
  ];
  missingSglangNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) sglangNegativeErrors)
  ) expectedSglangNegativeFields;
in
{
  checks = {
    module-registry-sync = pkgs.runCommand "module-registry-sync" { } ''
      ${lib.optionalString (inRegistryNoDisk != [ ]) ''
        echo "Modules in contracts.ncl selfModules but missing from modules/default.nix:"
        echo "  ${lib.concatStringsSep " " inRegistryNoDisk}"
        echo ""
      ''}
      ${lib.optionalString (onDiskNoRegistry != [ ]) ''
        echo "Modules in modules/default.nix but not registered in contracts.ncl:"
        echo "  ${lib.concatStringsSep " " onDiskNoRegistry}"
        echo ""
      ''}
      ${lib.optionalString (modulesWithoutSchema != [ ]) ''
        echo "Modules missing schema.ncl (needed for settings contract validation):"
        echo "  ${lib.concatStringsSep " " modulesWithoutSchema}"
        echo ""
      ''}
      ${lib.optionalString
        (inRegistryNoDisk != [ ] || onDiskNoRegistry != [ ] || modulesWithoutSchema != [ ])
        ''
          echo "Fix: update contracts.ncl and/or add schema.ncl to each module"
          exit 1
        ''
      }
      touch $out
    '';

    sglang-diffusion-settings = pkgs.runCommand "sglang-diffusion-settings" { } ''
      ${lib.optionalString (sglangPositiveErrors != [ ]) ''
        echo "Valid sglang-diffusion settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingSglangNegativeFields != [ ]) ''
        echo "Invalid sglang-diffusion settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSglangNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    lemonade-krea2-rendering = pkgs.runCommand "lemonade-krea2-rendering" { } ''
      ${lib.optionalString (lemonadePositiveErrors != [ ]) ''
        echo "Valid Lemonade Krea2 settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" lemonadePositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingRenderedKreaRoles != [ ]) ''
        echo "Krea2 user model did not render required checkpoint roles:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingRenderedKreaRoles)}
        exit 1
      ''}
      ${lib.optionalString (!(lemonadeKreaUserModel ? image_defaults)) ''
        echo "Krea2 user model did not render image_defaults"
        exit 1
      ''}
      ${lib.optionalString ((lemonadeKreaRecipeOptions.sdcpp_args or "") != lemonadeTestSdCppArgs) ''
        echo "Krea2 recipe options did not render sdcpp_args"
        exit 1
      ''}
      ${lib.optionalString (kreaLlamaOnlyRecipeFields != [ ]) ''
        echo "Krea2 recipe options included llama.cpp-only fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" kreaLlamaOnlyRecipeFields)}
        exit 1
      ''}
      ${lib.optionalString (missingLlmRecipeFields != [ ]) ''
        echo "LLM recipe options did not preserve expected llama.cpp fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingLlmRecipeFields)}
        exit 1
      ''}
      ${lib.optionalString (missingLemonadeNegativeFields != [ ]) ''
        echo "Invalid Lemonade Krea2 settings did not report expected missing roles:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingLemonadeNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" lemonadeNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';
  };
}
