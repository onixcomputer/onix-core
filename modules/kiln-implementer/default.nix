{ schema }:
{ lib, ... }:
let
  ms = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "kiln-implementer";
    description = "Opt-in pinned Kiln implementation stages with separate authority";
    categories = [ "system" ];
    readme = "Explicit bounded stages, immutable cohort and no automatic landing or activation";
  };
  roles.default = {
    description = "Explicit admitted implementation coordinator and Lattice executor host";
    interface = ms.mkInterface schema.default;
    perInstance = { extendSettings, ... }: {
      nixosModule =
        _:
        let
          settings = extendSettings (ms.mkDefaults schema.default);
        in
        {
          imports = [ ./nixos.nix ];
          services.kiln-implementer = {
            inherit (settings)
              enable
              selectedCampaignEnable
              selectedCampaignId
              selectedCampaignDatabase
              selectedImplementationDatabase
              selectedCampaignBoundInputDirectory
              selectedCampaignCandidateExportDirectory
              selectedCampaignWorkspaceRoot
              selectedCampaignDataGid
              selectedCampaignNetworkNamespace
              selectedCampaignCredentialPath
              runtimeName
              repositories
              workClasses
              intakeCredential
              publisherCredential
              coordinatorUid
              executorUid
              publisherUid
              verifierUid
              modelNetworkNamespace
              canonicalCiStatePaths
              ;
            selectedCampaignProfile = settings.selectedCampaignProfilePath;
            cohort = settings.cohortPath;
            configuration = settings.configurationPath;
            attemptBundle = settings.attemptBundlePath;
            ciServiceProfile = settings.ciServiceProfilePath;
          };
        };
    };
  };
  perMachine = _: { nixosModule = _: { }; };
}
