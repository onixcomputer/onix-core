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
in
rustPlatform.buildRustPackage {
  pname = "rwkv-layer-harness";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  RWKV_LAYER_MODEL = model;
  RWKV_LAYER_MODEL_BLAKE3 = modelBlake3;

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
    grep -F '"continued_after_eos": false' "$fixture_root/decode-first.json"
    grep -F 'No decoded text or tokenizer mapping is established.' "$fixture_root/decode-first.json"

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

    if grep -E 'std::process::Command|Command::new|/dev/tenstorrent|TT_VISIBLE_DEVICES|Metalium|owner-control|retry' \
      ${./src/lib.rs} ${./src/main.rs} ${./src/bin/rwkv-token-harness.rs} ${./src/bin/rwkv-decode-harness.rs}; then
      echo "rwkv-layer-harness must not contain hardware or process orchestration" >&2
      exit 1
    fi

    cat "$fixture_root/first.json"
    cat "$fixture_root/token-first.json"
    cat "$fixture_root/decode-first.json"
    runHook postInstallCheck
  '';

  passthru = {
    inherit model;
  };

  meta = {
    description = "Device-free real-weight RWKV-7 layer, greedy-token, and stateful-decode CPU reference";
    license = lib.licenses.mit;
    mainProgram = "rwkv-layer-harness";
    platforms = lib.platforms.linux;
  };
}
