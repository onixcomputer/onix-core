{
  fetchurl,
  lib,
  rustPlatform,
}:
let
  modelRevision = "d81965cb4e1a9f96696b4f70b84212b8f2e43216";
  model = fetchurl {
    name = "rwkv7-goose-world2.8-0.1b-${modelRevision}.safetensors";
    url = "https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF/resolve/${modelRevision}/model.safetensors";
    hash = "sha256-uWqL3CHhX3HgyVZT3MO+ieVkthmtUHPJ7b+9B/eElFM=";
  };
  modelBlake3 = "905f82048a64b881f9267117a398feb8a8a92bcc5233666bf67904e0d899d0e5";
  tokenizerArtifact =
    name: hash:
    fetchurl {
      inherit name hash;
      url = "https://huggingface.co/RWKV/RWKV7-Goose-World2.8-0.1B-HF/resolve/${modelRevision}/${name}";
    };
  tokenizerVocabulary = tokenizerArtifact "rwkv_vocab_v20230424.txt" "sha256-5t7j1OMbTVxArJlQisbHAc7vS+1oG/IWfOmpCFUryok=";
  tokenizerConfig = tokenizerArtifact "tokenizer_config.json" "sha256-TgOqD11rGkAGoNnp8HDwFBjnNKsXx8SPKDM1lta9Xik=";
  addedTokens = tokenizerArtifact "added_tokens.json" "sha256-o0nK5s2qaAz2/A0pKbFvKp7bQ+twJ7LjRLHKgGOFT7k=";
  tokenizerImplementation = tokenizerArtifact "hf_rwkv_tokenizer.py" "sha256-qspeag9W0EPKFlTp3K+Qb888DgO1FyhjrXUGDoaFoQ4=";
  specialTokensMap = tokenizerArtifact "special_tokens_map.json" "sha256-H1EppN7ADOM+XFzScmyVKyKkeCcyHu08UY1DXUpkYBU=";
  modelConfig = tokenizerArtifact "config.json" "sha256-VcFZ/IlA4WVXpCsE8K7QN0TxdiIcwSY3aUqx9+EMTG8=";
  generationConfig = tokenizerArtifact "generation_config.json" "sha256-2milZURvylpqKvSzCIkS6VOWX7+m6WgBmhTXVj1Y2Tc=";
  expectedSecondTokenFingerprints = [
    "6e5391b0a6ddd727c0a5359b18676bd5d3dfd3fcc69f088da9fb15bba69934e3"
    "34cbe8c4586627577d9a51d49db1b6a2106b50f616ae5983593b0c4196488b33"
    "5a8b7ce512d92fb71038218c03441012ad096e990749aa7020c94ae9ed9cd176"
    "5aeeebb2d8d1d7f83b82df3fc1a810c4191ff297cae604d010001640ded69650"
    "7f43c153e6a3b25b1dc0d8aef8707aafb7a8983d49e22f42917ae0663c10cd51"
    "1aebc84d2384d3d3550aa9f4a123912ecad1ae43c6f127bcdc1207fbafb2b88e"
  ];
  expectedFinalStateFingerprint = "63718d8139e7a70770d8ca7b0663faca0d87ea3d5b99a45a5d895a827cec868f";
  expectedFinalOutputFingerprint = "cca5dded173404e19115bc749f25aab0c26200282a739bb3da98923d2d9a8e26";
  expectedModelLayerCount = 12;
  expectedGeneratedTokenId = 2;
  expectedGeneratedLogit = "2.8641083";
  expectedRunnerUpTokenId = 33;
  expectedRunnerUpLogit = "0.89640886";
  expectedGreedyMargin = "1.9676995";
  expectedTokenFinalHiddenFingerprint = "af8775318ae4b28af27709dbe1052a8ffcd5bc58f3ae209dea0913801b334f70";
  expectedTokenLogitsFingerprint = "31e5a4c2f979966c1a8ac72b3af8daa16db0f61d33297f7aadea4196816b9662";
  expectedTokenStatesFingerprint = "7edee48128b2bb3f9f874e9cbc491d44a2af7f5bb19c53a595ff0bc8eed108fe";
  expectedDecodeStepCount = 3;
  expectedDecodeTokenId = 1;
  expectedDecodeLogits = [
    "0.04493069"
    "6.9543834"
    "6.486726"
  ];
  expectedDecodeFingerprints = [
    "04f6971c67f2fb45e3e8d26164a872b6e7d4d8ba847f26ec170fcd347df6e89f"
    "762581cfa10ae11cde207349bd844e59fdaceca5c9288db937928c4f356c3263"
    "e61647dfa4e341599f939181919100509c652797050b76b4f2f80ada7134a591"
    "812728ef2bd878f91df9d2ede34aebdffa19fc83c25319d8cf24d1b041bfa30a"
    "3daaa9712bb4851e5fcccdc6d2b7644c9c29b495c7ece0f483e97cddf782be9d"
    "15658cb672bb56cec6132e4b72463a5966db26fdc471ca631b3a308112bf76a2"
    "401b9ad0f87cfc436fc53fe3d1e977c6aaba1546582e9f07daf46549730ed7ab"
    "ccb66a0dde8fc0490872092dce9aa3b778a3b1d5ce0bb1d256d130ec7a423917"
    "56ab5c6de04f5e359a7d26390ce36b0c7551ef41dbcb998373ab4c2f0f344ecb"
  ];
  expectedMinimumStateCarryDivergence = "32.84725";
  expectedTokenizerBlake3 = [
    "3997a74891dd68ced8daadae0d7475274b08988c9263ca042896c8106967aef2"
    "b2411eb362aefa260493811c9414e8da589a19d6cec44e8456953507e293755e"
    "02893c22a1e92502fdd31ba4d57b6e574692023505be7ba82d68d1e3142ff02f"
    "0a2a88e97b455858e03bbbc83bb0228d8f36c2731fcb91cd94f05e2930e2aa24"
    "751ae3ea4b59073218a85facbee1536739b0aa26d5d5670e11ef6815e5bac870"
    "113edfd55813d327ae7e37987ee9c5ed123c69fa809670b3a0bcc07fd1e9295d"
    "2288838a56ea704a85691828bbc7f0ab2934c949b13a4d8f3af1b13d955ac2fa"
  ];
  expectedTextPromptIdsBlake3 = "f5a4ecffc7fe3f4205d095934a95d00ed5a633a02d8f6153fa9cc240c4488778";
  expectedTextGeneratedIdsBlake3 = "e714e3dc953afc6b24fb83aa0e972af26ec6a3145414a371894c4f1fb505fe0c";
  expectedTextGeneratedTokenIds = [
    3880
    45
    308
  ];
  expectedTextGeneratedLogits = [
    "7.5499983"
    "9.128329"
    "6.486315"
  ];
  expectedTextFingerprints = [
    "222a0718f72e1324673a043a6d9d9b3c5a7281457f481e7eae2c48e992165787"
    "842a6494a5eb01be12800aaf157054b7f87bce6753f96e83bbe8afcc5271344a"
    "4448243fad8b4b6e99cda3d36051c1c51a3c04e3b15981e7e91f9dfa638aea63"
    "b2b4f4efbf5e5ca66006760a5bceba3709c9063fdb817ccba6a989868ce1f9bb"
    "7b38e06b121655b31f405426c530a86983ac0fe406a5f92ae37489da1140372f"
    "a5de08fbd73c84cedc1032bb29f64f31c2c984d886c4928acdfc318253c0faec"
  ];
  expectedTextStateCarryDivergence = "21.653366";
in
rustPlatform.buildRustPackage {
  pname = "rwkv-layer-harness";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  RWKV_LAYER_MODEL = model;
  RWKV_LAYER_MODEL_BLAKE3 = modelBlake3;
  RWKV_TOKENIZER_VOCABULARY = tokenizerVocabulary;
  RWKV_TOKENIZER_CONFIG = tokenizerConfig;
  RWKV_TOKENIZER_ADDED_TOKENS = addedTokens;
  RWKV_TOKENIZER_IMPLEMENTATION = tokenizerImplementation;
  RWKV_SPECIAL_TOKENS_MAP = specialTokensMap;
  RWKV_MODEL_CONFIG = modelConfig;
  RWKV_GENERATION_CONFIG = generationConfig;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    set -euo pipefail

    fixture_root="$(mktemp -d)"
    $out/bin/rwkv-layer-harness >"$fixture_root/first.json"
    $out/bin/rwkv-layer-harness >"$fixture_root/second.json"
    cmp "$fixture_root/first.json" "$fixture_root/second.json"

    grep -F '"model_id": "RWKV/RWKV7-Goose-World2.8-0.1B-HF"' "$fixture_root/first.json"
    grep -F '"revision": "${modelRevision}"' "$fixture_root/first.json"
    grep -F '"blake3": "${modelBlake3}"' "$fixture_root/first.json"
    grep -F '"hidden_size": 768' "$fixture_root/first.json"
    grep -F '"head_size": 64' "$fixture_root/first.json"
    grep -F '"head_count": 12' "$fixture_root/first.json"
    grep -F '"intermediate_size": 3072' "$fixture_root/first.json"
    grep -F '"token_ids": [' "$fixture_root/first.json"
    grep -F '"arithmetic_precision": "cpu_fp32_from_bf16"' "$fixture_root/first.json"
    grep -F '"finite": true' "$fixture_root/first.json"
    grep -F '"maximum_oracle_state_deviation":' "$fixture_root/first.json"
    grep -F '"maximum_oracle_output_deviation":' "$fixture_root/first.json"
    for expected_fingerprint in ${lib.escapeShellArgs expectedSecondTokenFingerprints}; do
      grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/first.json"
    done
    grep -F '"blake3": "${expectedFinalStateFingerprint}"' "$fixture_root/first.json"
    grep -F '"blake3": "${expectedFinalOutputFingerprint}"' "$fixture_root/first.json"
    grep -F 'No generated token is established.' "$fixture_root/first.json"

    $out/bin/rwkv-token-harness >"$fixture_root/token-first.json"
    $out/bin/rwkv-token-harness >"$fixture_root/token-second.json"
    cmp "$fixture_root/token-first.json" "$fixture_root/token-second.json"
    grep -F '"layer_count": ${toString expectedModelLayerCount}' "$fixture_root/token-first.json"
    grep -F '"prefix_token_ids": [' "$fixture_root/token-first.json"
    grep -F '"generated_token_id": ${toString expectedGeneratedTokenId}' "$fixture_root/token-first.json"
    grep -F '"generated_logit": ${expectedGeneratedLogit}' "$fixture_root/token-first.json"
    grep -F '"runner_up_token_id": ${toString expectedRunnerUpTokenId}' "$fixture_root/token-first.json"
    grep -F '"runner_up_logit": ${expectedRunnerUpLogit}' "$fixture_root/token-first.json"
    grep -F '"greedy_margin": ${expectedGreedyMargin}' "$fixture_root/token-first.json"
    grep -F '"blake3": "${expectedTokenFinalHiddenFingerprint}"' "$fixture_root/token-first.json"
    grep -F '"blake3": "${expectedTokenLogitsFingerprint}"' "$fixture_root/token-first.json"
    grep -F '"blake3": "${expectedTokenStatesFingerprint}"' "$fixture_root/token-first.json"
    grep -F '"head_oracle_logit_deviation": 0.0' "$fixture_root/token-first.json"
    grep -F 'The selected token is not executed as a recurrent third step.' "$fixture_root/token-first.json"
    grep -F 'No P150 numerical parity is established.' "$fixture_root/token-first.json"

    $out/bin/rwkv-decode-harness >"$fixture_root/decode-first.json"
    $out/bin/rwkv-decode-harness >"$fixture_root/decode-second.json"
    cmp "$fixture_root/decode-first.json" "$fixture_root/decode-second.json"
    grep -F '"seed_token_id": ${toString expectedDecodeTokenId}' "$fixture_root/decode-first.json"
    grep -F '"generated_step_count": ${toString expectedDecodeStepCount}' "$fixture_root/decode-first.json"
    generated_count="$(grep -c '"generated_token_id": ${toString expectedDecodeTokenId}' "$fixture_root/decode-first.json")"
    test "$generated_count" -eq ${toString expectedDecodeStepCount}
    for expected_logit in ${lib.escapeShellArgs expectedDecodeLogits}; do
      grep -F "\"generated_logit\": $expected_logit" "$fixture_root/decode-first.json"
    done
    for expected_fingerprint in ${lib.escapeShellArgs expectedDecodeFingerprints}; do
      grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/decode-first.json"
    done
    grep -F '"maximum_replay_hidden_deviation": 0.0' "$fixture_root/decode-first.json"
    grep -F '"maximum_replay_logits_deviation": 0.0' "$fixture_root/decode-first.json"
    grep -F '"maximum_replay_state_deviation": 0.0' "$fixture_root/decode-first.json"
    grep -F '"minimum_retained_vs_reset_hidden_deviation": ${expectedMinimumStateCarryDivergence}' "$fixture_root/decode-first.json"
    grep -F '"model_config_eos_token_id": 2' "$fixture_root/decode-first.json"
    grep -F '"continued_after_model_config_eos": false' "$fixture_root/decode-first.json"
    grep -F 'No decoded text or tokenizer mapping is established.' "$fixture_root/decode-first.json"

    $out/bin/rwkv-text-harness >"$fixture_root/text-first.json"
    $out/bin/rwkv-text-harness >"$fixture_root/text-second.json"
    cmp "$fixture_root/text-first.json" "$fixture_root/text-second.json"
    grep -F '"vocabulary_entry_count": 65529' "$fixture_root/text-first.json"
    grep -F '"model_config_bos_token_id": 1' "$fixture_root/text-first.json"
    grep -F '"model_config_eos_token_id": 2' "$fixture_root/text-first.json"
    grep -F '"tokenizer_bos_token_id": 0' "$fixture_root/text-first.json"
    grep -F '"byte_vocabulary_eos_token_id": 261' "$fixture_root/text-first.json"
    grep -F '"tokenizer_wrapper_eos_token_id": 65530' "$fixture_root/text-first.json"
    grep -F '"generation_config_bos_token_id": 0' "$fixture_root/text-first.json"
    grep -F '"generation_config_eos_token_id": 0' "$fixture_root/text-first.json"
    for expected_blake3 in ${lib.escapeShellArgs expectedTokenizerBlake3}; do
      grep -F "\"blake3\": \"$expected_blake3\"" "$fixture_root/text-first.json"
    done
    for fixture_name in empty tokenizer_eos overlapping_prefix ascii unicode control_bytes byte_fixed_chat_prompt wrapper_fixed_chat_prompt; do
      grep -F "\"name\": \"$fixture_name\"" "$fixture_root/text-first.json"
    done
    grep -F '"prompt_token_ids_blake3": "${expectedTextPromptIdsBlake3}"' "$fixture_root/text-first.json"
    grep -F '"generated_token_ids_blake3": "${expectedTextGeneratedIdsBlake3}"' "$fixture_root/text-first.json"
    grep -F '"generated_bytes_hex": "2048692c2049"' "$fixture_root/text-first.json"
    grep -F '"generated_text": " Hi, I"' "$fixture_root/text-first.json"
    grep -F '"stop_reason": "generation_step_limit"' "$fixture_root/text-first.json"
    for expected_token_id in ${lib.escapeShellArgs (map toString expectedTextGeneratedTokenIds)}; do
      grep -F "\"generated_token_id\": $expected_token_id" "$fixture_root/text-first.json"
    done
    for expected_logit in ${lib.escapeShellArgs expectedTextGeneratedLogits}; do
      grep -F "\"generated_logit\": $expected_logit" "$fixture_root/text-first.json"
    done
    for expected_fingerprint in ${lib.escapeShellArgs expectedTextFingerprints}; do
      grep -F "\"blake3\": \"$expected_fingerprint\"" "$fixture_root/text-first.json"
    done
    grep -F '"maximum_replay_hidden_deviation": 0.0' "$fixture_root/text-first.json"
    grep -F '"maximum_replay_state_deviation": 0.0' "$fixture_root/text-first.json"
    grep -F '"minimum_retained_vs_reset_hidden_deviation": ${expectedTextStateCarryDivergence}' "$fixture_root/text-first.json"
    grep -F 'No P150 numerical parity is established.' "$fixture_root/text-first.json"

    if $out/bin/rwkv-layer-harness unexpected-argument \
      >"$fixture_root/argument-rejection.log" 2>&1; then
      echo "rwkv-layer-harness accepted a caller-controlled argument" >&2
      exit 1
    fi
    grep -F 'does not accept arguments' "$fixture_root/argument-rejection.log"

    if $out/bin/rwkv-token-harness unexpected-argument \
      >"$fixture_root/token-argument-rejection.log" 2>&1; then
      echo "rwkv-token-harness accepted a caller-controlled argument" >&2
      exit 1
    fi
    grep -F 'does not accept arguments' "$fixture_root/token-argument-rejection.log"

    if $out/bin/rwkv-decode-harness unexpected-argument \
      >"$fixture_root/decode-argument-rejection.log" 2>&1; then
      echo "rwkv-decode-harness accepted a caller-controlled argument" >&2
      exit 1
    fi
    grep -F 'does not accept arguments' "$fixture_root/decode-argument-rejection.log"

    if $out/bin/rwkv-text-harness unexpected-argument \
      >"$fixture_root/text-argument-rejection.log" 2>&1; then
      echo "rwkv-text-harness accepted a caller-controlled argument" >&2
      exit 1
    fi
    grep -F 'does not accept arguments' "$fixture_root/text-argument-rejection.log"

    if grep -E 'std::process::Command|Command::new|/dev/tenstorrent|TT_VISIBLE_DEVICES|Metalium|owner-control|retry' \
      ${./src/lib.rs} ${./src/main.rs} ${./src/bin/rwkv-token-harness.rs} ${./src/bin/rwkv-decode-harness.rs} ${./src/bin/rwkv-text-harness.rs}; then
      echo "rwkv-layer-harness must not contain hardware or process orchestration" >&2
      exit 1
    fi

    cat "$fixture_root/first.json"
    cat "$fixture_root/token-first.json"
    cat "$fixture_root/decode-first.json"
    cat "$fixture_root/text-first.json"
    runHook postInstallCheck
  '';

  passthru = {
    inherit
      addedTokens
      generationConfig
      model
      modelConfig
      specialTokensMap
      tokenizerConfig
      tokenizerImplementation
      tokenizerVocabulary
      ;
  };

  meta = {
    description = "Device-free real-weight RWKV-7 layer, tokenizer, stateful-decode, and fixed-text CPU reference";
    license = lib.licenses.mit;
    mainProgram = "rwkv-layer-harness";
    platforms = lib.platforms.linux;
  };
}
