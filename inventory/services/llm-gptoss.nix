_: {
  instances = {
    # vLLM instance on aspen1 (AMD Strix Halo with 124GB unified memory)
    # ArliAI GPT-OSS 20B Derestricted (~40GB bf16)
    "llm-gptoss" = {
      module.name = "llm";
      module.input = "self";

      roles.server = {
        # Direct machine assignment - only aspen1 has sufficient memory
        machines."aspen1" = { };

        settings = {
          serviceType = "vllm";
          port = 8000;
          host = "0.0.0.0";
          enableGPU = true;
          model = "ArliAI/gpt-oss-20b-Derestricted";

          # Disable auto-start until we verify stability
          autoStart = false;

          # vLLM arguments for 20B on 124GB unified memory
          # Docker container capped at 115GB with OOM protection
          # 20B bf16 model ≈ 40GB, leaving ~75GB for KV cache
          extraArgs = [
            "--max-model-len"
            "32768" # Full 32K context
            "--gpu-memory-utilization"
            "0.85" # 85% of GPU memory for KV cache (safe with Docker memory cap)
            "--max-num-seqs"
            "16" # Concurrent requests
            "--enforce-eager" # Required for ROCm stability
            "--dtype"
            "bfloat16"
            "--kv-cache-dtype"
            "auto" # Use bf16 for KV cache too
          ];
        };
      };
    };
  };
}
