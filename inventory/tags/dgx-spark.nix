# DGX Spark machine tag.
#
# Uses the accepted device-free DGX service policy module (modules/dgx-machine)
# as the base and enables the local GPU max-clock serving power profile
# (modules/dgx-spark-power). Keeping the power profile here is intentional:
# it is applied at boot and released on stop, and no other module owns it.
{
  ...
}:
{
  imports = [
    ../../modules/dgx-machine
    ../../modules/dgx-spark-power
  ];

  services.dgx-spark-power.enable = true;
}
