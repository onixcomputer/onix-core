# shellcheck shell=bash
set -euo pipefail

metrics_file=/var/lib/prometheus-node-exporter-text-files/amd_gpu_metrics.prom
temp_file=

cleanup() {
  if [[ -n $temp_file ]]; then
    rm -f -- "$temp_file" || true
  fi
}

fail() {
  local message=$1
  rm -f -- "$metrics_file" 2>/dev/null || true
  printf 'amd-gpu-exporter: %s\n' "$message" >&2
  exit 1
}

trap cleanup EXIT

if ! gpu_json=$(rocm-smi --showuse --showtemp --showmemuse --showpower --json); then
  fail 'rocm-smi collection failed; removing stale metrics'
fi

if ! metric_samples=$(printf '%s\n' "$gpu_json" | jq -er '
  def numeric($raw; $key):
    if ($raw | type) == "number" then
      $raw
    elif ($raw | type) == "string" then
      ($raw | gsub("^[[:space:]]+|[[:space:]]+$"; "") | sub("[[:space:]]*(%|[cCwW])$"; "")) as $value
      | try ($value | tonumber) catch error("invalid numeric rocm-smi value for \($key): \($raw)")
    else
      error("unsupported rocm-smi value type for \($key)")
    end;

  def metric($gpu; $key):
    if ($gpu | has($key)) then
      numeric($gpu[$key]; $key)
    else
      error("missing rocm-smi metric: \($key)")
    end;

  def temperature_metric($gpu):
    [
      "Temperature (Sensor edge) (C)",
      "Temperature (Sensor junction) (C)",
      "Temperature (Sensor memory) (C)",
      "Temperature (Sensor HBM 0) (C)",
      "Temperature (Sensor HBM 1) (C)",
      "Temperature (Sensor HBM 2) (C)",
      "Temperature (Sensor HBM 3) (C)"
    ] as $keys
    | [ $keys[] as $key | select($gpu | has($key)) | numeric($gpu[$key]; $key) ] as $values
    | if ($values | length) == 0 then
        error("missing rocm-smi metric: GPU temperature")
      else
        $values[0]
      end;

  def power_metric($gpu):
    [
      "Average Graphics Package Power (W)",
      "Current Socket Graphics Package Power (W)"
    ] as $keys
    | [ $keys[] as $key | select($gpu | has($key)) | numeric($gpu[$key]; $key) ] as $values
    | if ($values | length) == 0 then
        error("missing rocm-smi metric: graphics package power")
      else
        $values[0]
      end;

  to_entries
  | map(select(.key | test("^card[0-9]+$")))
  | sort_by(.key) as $gpus
  | if ($gpus | length) == 0 then
      error("no GPU records in rocm-smi output")
    else
      [
        $gpus[]
        | . as $entry
        | ($entry.key | ltrimstr("card")) as $device
        | $entry.value as $gpu
        | "amd_gpu_utilization_percent{device=\"\($device)\"} \(metric($gpu; "GPU use (%)"))",
          "amd_gpu_temperature_celsius{device=\"\($device)\"} \(temperature_metric($gpu))",
          "amd_gpu_memory_utilization_percent{device=\"\($device)\"} \(metric($gpu; "GPU Memory Allocated (VRAM%)"))",
          "amd_gpu_power_draw_watts{device=\"\($device)\"} \(power_metric($gpu))"
      ]
      | join("\n")
    end
'); then
  fail 'rocm-smi JSON did not contain all required numeric metrics; removing stale metrics'
fi

if [[ -z $metric_samples ]]; then
  fail 'rocm-smi returned no GPU metrics; removing stale metrics'
fi

if ! temp_file=$(mktemp "${metrics_file}.tmp.XXXXXX"); then
  fail 'cannot create temporary metrics file'
fi

if ! {
  printf '%s\n' \
    '# HELP amd_gpu_utilization_percent AMD GPU utilization percentage' \
    '# TYPE amd_gpu_utilization_percent gauge' \
    '# HELP amd_gpu_temperature_celsius AMD GPU temperature in Celsius' \
    '# TYPE amd_gpu_temperature_celsius gauge' \
    '# HELP amd_gpu_memory_utilization_percent AMD GPU memory utilization percentage' \
    '# TYPE amd_gpu_memory_utilization_percent gauge' \
    '# HELP amd_gpu_power_draw_watts AMD GPU power draw in watts' \
    '# TYPE amd_gpu_power_draw_watts gauge'
  printf '%s\n' "$metric_samples"
} >"$temp_file"; then
  fail 'cannot write temporary metrics file'
fi

if ! chmod 0644 -- "$temp_file"; then
  fail 'cannot make metrics file readable by node-exporter'
fi

if ! mv -f -- "$temp_file" "$metrics_file"; then
  fail 'cannot atomically publish metrics file'
fi
temp_file=
