{ lib }:
let
  defaultRecipe = "llamacpp";
  llamaCppRecipe = "llamacpp";
  sdCppRecipe = "sd-cpp";
  userModelPrefix = "user.";
  requiredCompositeMainRole = "main";
  requiredSdCppCompositeRoles = [
    requiredCompositeMainRole
    "text_encoder"
    "vae"
  ];

  modelRecipe = model: model.recipe or defaultRecipe;
  modelImageDefaults = model: model.imageDefaults or (model.image_defaults or null);
  modelRecipeOptions = model: model.recipeOptions or (model.recipe_options or { });
  missingRoles =
    checkpoints: roles: builtins.filter (role: !(builtins.hasAttr role checkpoints)) roles;
  formatMissingRole =
    name: role: "customModels.${name}.checkpoints.${role}: required for sd-cpp multi-checkpoint models";
in
rec {
  inherit
    defaultRecipe
    llamaCppRecipe
    modelRecipe
    sdCppRecipe
    userModelPrefix
    ;

  customModelAssetErrors =
    customModels:
    lib.flatten (
      lib.mapAttrsToList (
        name: model:
        let
          recipe = modelRecipe model;
          checkpoints = model.checkpoints or { };
          requiredRoles =
            if model ? checkpoints && recipe == sdCppRecipe then
              requiredSdCppCompositeRoles
            else if model ? checkpoints then
              [ requiredCompositeMainRole ]
            else
              [ ];
        in
        map (formatMissingRole name) (missingRoles checkpoints requiredRoles)
      ) customModels
    );

  renderUserModel =
    _name: model:
    let
      imageDefaults = modelImageDefaults model;
    in
    {
      recipe = modelRecipe model;
    }
    // lib.optionalAttrs (model ? checkpoint) { inherit (model) checkpoint; }
    // lib.optionalAttrs (model ? checkpoints) { inherit (model) checkpoints; }
    // lib.optionalAttrs (model ? size) { inherit (model) size; }
    // lib.optionalAttrs (model ? mmproj) { inherit (model) mmproj; }
    // lib.optionalAttrs (model ? labels) { inherit (model) labels; }
    // lib.optionalAttrs (imageDefaults != null) { image_defaults = imageDefaults; };

  renderUserModels = customModels: builtins.mapAttrs renderUserModel customModels;

  renderModelRecipeOptions =
    {
      contextSize,
      backend,
      effectiveExtraArgs,
      ...
    }:
    _name: model:
    let
      recipe = modelRecipe model;
      llamaCppBase = {
        ctx_size = contextSize;
        llamacpp_backend = if backend == "system" then "vulkan" else backend;
      }
      // lib.optionalAttrs (effectiveExtraArgs != "") {
        llamacpp_args = effectiveExtraArgs;
      };
      recipeBase = if recipe == llamaCppRecipe then llamaCppBase else { };
    in
    recipeBase // modelRecipeOptions model;

  renderRecipeOptions =
    args@{ customModels, ... }:
    lib.filterAttrs (_name: value: value != { }) (
      lib.mapAttrs' (
        name: model:
        lib.nameValuePair "${userModelPrefix}${name}" (renderModelRecipeOptions args name model)
      ) customModels
    );
}
