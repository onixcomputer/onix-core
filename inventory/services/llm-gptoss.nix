_: {
  instances = {
    # vLLM instance on aspen1 (AMD Strix Halo with 124GB unified memory)
    # Using Qwen2.5-32B-Instruct - fits with room for KV cache
    # Memory breakdown: ~61GB weights + ~50GB KV cache headroom
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
          model = "Qwen/Qwen2.5-32B-Instruct";

          # vLLM arguments optimized for Strix Halo with 124GB
          extraArgs = [
            "--max-model-len"
            "16384" # Reduced context for 32B model to fit KV cache
            "--gpu-memory-utilization"
            "0.92" # ~114GB usable
            "--max-num-seqs"
            "8" # Fewer concurrent requests for larger model
            "--enforce-eager" # Required for ROCm stability
            "--dtype"
            "bfloat16" # Optimal for inference
          ];
        };
      };
    };
  };
}
