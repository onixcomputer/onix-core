# r[impl onix.radicle_replica.configuration]
# r[impl onix.radicle_replica.identity_distinct]
{
  "britton-desktop" = {
    deploymentTarget = "root@100.110.43.11";
    failureDomain = "britton-desktop-workstation";
    nodeAddress = "100.110.43.11";
    nodeFingerprint = "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg";
    stateDataset = "datapool/radicle-seed";
  };
  aspen3 = {
    deploymentTarget = "root@aspen3";
    failureDomain = "aspen3-mobile-workstation";
    nodeAddress = "100.108.13.4";
    nodeFingerprint = "SHA256:TEuGqHuV/3kGZzGiqUGCkCYG8ITfhV3TvJUjddv8fb0";
    stateDataset = "zroot/radicle-seed";
  };
}
