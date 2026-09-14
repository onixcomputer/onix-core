# Hardware inventory queries for tag modules.
#
# Tag modules decide policy from recorded hardware facts, so a tag that needs a
# device cannot be assigned to a host that has no such device.
_:
let
  # Network controller drivers that indicate an RDMA-capable device.
  rdmaCapableDrivers = [
    "bnxt_re"
    "efa"
    "erdma"
    "ib_qib"
    "ice"
    "irdma"
    "mana_ib"
    "mlx4_core"
    "mlx5_core"
    "qedr"
    "rxe"
    "siw"
    "vmw_pvrdma"
  ];

  facterPath =
    { self, hostname }:
    "${self}/machines/${hostname}/facter.json";

  facter =
    { self, hostname }:
    let
      path = facterPath { inherit self hostname; };
    in
    if builtins.pathExists path then builtins.fromJSON (builtins.readFile path) else { };
in
{
  inherit rdmaCapableDrivers facterPath facter;

  # True when the host inventory lists a network controller with an
  # RDMA-capable driver. A host with no inventory file fails closed.
  hasRdmaController =
    { self, hostname }:
    let
      controllers = (facter { inherit self hostname; }).hardware.network_controller or [ ];
      driverOf = controller: controller.driver_module or controller.driver or "";
    in
    builtins.any (controller: builtins.elem (driverOf controller) rdmaCapableDrivers) controllers;
}
