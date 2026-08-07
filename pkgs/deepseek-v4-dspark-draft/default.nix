# DeepSeek-V4-Flash-0731 DSpark draft GGUF, converted from the official
# checkpoint with the pinned llama.cpp converter.
#
# Ready-made drafters on Hugging Face do not work with the pinned runtime:
# the MXFP4-Q8_0 file declares an unknown architecture, and the dflash
# variant ships `no_vocab` tokenizer metadata, so llama.cpp never reads
# the mask token id and every draft decode fails. Converting locally with
# --target-model-dir embeds the real DeepSeek tokenizer, which is the
# layout the verified Strix Halo deployment used.
{
  pkgs,
}:
let
  # r[onix.aspen1.deepseek.runtime]
  revision = "9e165c30e2704aec5d9d593cce3eebd58bbef1cb";
  baseUrl = "https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731/resolve/${revision}";

  fetchOfficial =
    file: hash:
    pkgs.fetchurl {
      url = "${baseUrl}/${file}";
      inherit hash;
    };

  configJson = fetchOfficial "config.json" "sha256-bI89LTtIcHVBuI8y8i7z8PimtX2FIygeK4082wrpoCM=";
  indexJson = fetchOfficial "model.safetensors.index.json" "sha256-mO+rRVzwjfu7qrpvVw4b8Qv5J9K0w8RTpZwvbw476Ss=";
  tokenizerJson = fetchOfficial "tokenizer.json" "sha256-j583yjf9xPX9NtXPTTsOg5LttOiU/RDMDXC0lXyGM88=";
  tokenizerConfigJson = fetchOfficial "tokenizer_config.json" "sha256-asjI3AZe0RgWHQLdUydJrj9SwkPerCeHITT64vUNhUc=";

  # The DSpark (MTP) tensors live in the last three shards of the official
  # checkpoint. Hashes are the Hugging Face LFS object ids (sha256).
  shard46 = fetchOfficial "model-00046-of-00048.safetensors" "sha256-XbkkypB+DZOs2XW9UHnDZicX+axwnyPQeb2PgW0p2d0=";
  shard47 = fetchOfficial "model-00047-of-00048.safetensors" "sha256-YoFhc/n24TayC0jjtvFmE6yeoCtWA/Y2koslMkSlSL0=";
  shard48 = fetchOfficial "model-00048-of-00048.safetensors" "sha256-zEN0K9JK5rzeo0OpFEL29mrtLP68xrI1RwIEhRzi+Kk=";

  # Same pinned revision as pkgs/llamacpp-rocm-dspark; fetched directly so
  # this package does not depend on flake-internal package wiring.
  llamaCppSrc = pkgs.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = "0b14b87d7c20cb753b94b96854dd7b45306fc696";
    hash = "sha256-ti8LjvWt6+Q6ybRLaqgbWo/CR5XF+GA7+fVrebPPymg=";
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.torch
    ps.transformers
    ps.safetensors
    ps.numpy
    ps.sentencepiece
    ps.protobuf
  ]);
in
pkgs.runCommand "deepseek-v4-flash-0731-dspark-draft"
  {
    nativeBuildInputs = [
      pythonEnv
      pkgs.jq
    ];
  }
  ''
    mkdir -p source tokenizer

    cp ${configJson} source/config.json
    cp ${shard46} source/model-00046-of-00048.safetensors
    cp ${shard47} source/model-00047-of-00048.safetensors
    cp ${shard48} source/model-00048-of-00048.safetensors

    cp ${tokenizerJson} source/tokenizer.json
    cp ${tokenizerConfigJson} source/tokenizer_config.json
    cp ${tokenizerJson} tokenizer/tokenizer.json
    cp ${tokenizerConfigJson} tokenizer/tokenizer_config.json

    jq '{metadata:.metadata,weight_map:(.weight_map|with_entries(select(.key|startswith("mtp."))))}' \
      ${indexJson} > source/model.safetensors.index.json

    export PYTHONPATH=${llamaCppSrc}/gguf-py''${PYTHONPATH:+:$PYTHONPATH}
    python ${llamaCppSrc}/convert_hf_to_gguf.py source \
      --dspark \
      --target-model-dir tokenizer \
      --outtype auto \
      --outfile $out
  ''
