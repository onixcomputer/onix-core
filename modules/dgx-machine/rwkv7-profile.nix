{
  alias = "rwkv7-g1i-13.3b-q6-k";
  repository = "shoumenchougou/RWKV7-G1i-13.3B-GGUF";
  revision = "cc972b4529e81eb4abd51fac2529caa773da48c4";
  file = "rwkv7-g1i-13.3b-Q6_K.gguf";
  # Hugging Face publishes the LFS object identity as SHA-256.
  sha256 = "dcd147f24f8749420ebc784c5b9c75ca2c0d2ced2e6f365be18ed97a4508d488";
  contextSize = 16384;
  gpuLayers = 999;
  flashAttention = false;
  noMmap = true;
  enableMetrics = true;
  extraArgs = [ ];
}
