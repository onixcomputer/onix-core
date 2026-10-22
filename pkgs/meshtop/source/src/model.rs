use serde::{Deserialize, Serialize};

/// Sampled counters and percentages; no command lines, usernames, or environment variables.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Snapshot {
    pub host: String,
    /// Optional for snapshots from agents that predate hardware naming.
    #[serde(default)]
    pub cpu_model: Option<String>,
    pub uptime_seconds: u64,
    pub cpu_percent: f32,
    pub cores_percent: Vec<f32>,
    pub load_average: [f64; 3],
    pub memory_used: u64,
    pub memory_total: u64,
    pub swap_used: u64,
    pub swap_total: u64,
    pub rx_bytes_per_second: u64,
    pub tx_bytes_per_second: u64,
    pub disks: Vec<DiskUsage>,
    /// None when talking to a pre-GPU-telemetry agent; Some([]) when no supported GPU is present.
    #[serde(default)]
    pub gpus: Option<Vec<GpuUsage>>,
    pub processes: Vec<ProcessUsage>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DiskUsage {
    pub mount: String,
    pub used: u64,
    pub total: u64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GpuUsage {
    pub label: String,
    pub utilization_percent: Option<f32>,
    pub memory_used: Option<u64>,
    pub memory_total: Option<u64>,
    pub temperature_celsius: Option<f32>,
    pub clock_mhz: Option<u32>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProcessUsage {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f32,
    pub memory_bytes: u64,
}
