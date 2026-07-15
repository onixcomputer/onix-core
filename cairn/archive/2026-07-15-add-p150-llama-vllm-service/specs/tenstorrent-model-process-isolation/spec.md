## MODIFIED Requirements

### Requirement: Supra-Router-51M preserves P150 capacity

r[onix.tenstorrent.concurrent_models.supra] The `llamacpp-server-supra-router` service MUST preserve port 13306, its model alias, deterministic sampling, routing output behavior, and GGUF model path, MUST use the CPU backend when its checked throughput equals or exceeds the former tuned Metalium deployment, and MUST NOT claim or reserve a Tenstorrent physical device needed by a supported larger model service.

#### Scenario: Supra returns a routing decision while both P150s serve larger models

- GIVEN VibeThinker owns physical card 0 and Llama-3.1-8B-Instruct owns physical card 1
- WHEN a structurally framed routing prompt is submitted to CPU Supra on port 13306 while VibeThinker handles a request
- THEN Supra returns the expected pipe-separated routing schema and fixed-input output
- AND Supra throughput does not materially regress from its former tuned Metalium deployment
- AND Supra does not acquire a Tenstorrent device lock, cache, or Inspector endpoint
