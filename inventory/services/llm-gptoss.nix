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

          # vLLM arguments for 20B on 124GB
          extraArgs = [
            "--max-model-len"
            "32768"
            "--gpu-memory-utilization"
            "0.92"
            "--max-num-seqs"
            "16"
            "--enforce-eager" # Required for ROCm stability
            "--dtype"
            "bfloat16"
          ];
        };
      };
    };
  };
}
