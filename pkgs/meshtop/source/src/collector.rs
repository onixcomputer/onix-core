use std::{
    fs::{self, File},
    io::Read,
    path::{Path, PathBuf},
    time::Instant,
};

use anyhow::{Context, Result};
use sysinfo::{Disks, Networks, ProcessRefreshKind, ProcessesToUpdate, System};

use crate::model::{DiskUsage, GpuUsage, ProcessUsage, Snapshot};

const MAX_HOST_BYTES: usize = 128;
const MAX_HARDWARE_BYTES: usize = 96;
const MAX_MOUNT_BYTES: usize = 160;
const MAX_PROCESS_NAME_BYTES: usize = 96;
const MAX_CORES: usize = 256;
const MAX_DISKS: usize = 32;
const MAX_PROCESSES: usize = 64;
const MAX_DRM_ENTRIES: usize = 128;
const MAX_GPUS: usize = 8;
const DRM_ROOT: &str = "/sys/class/drm";
const UDEV_DATA_ROOT: &str = "/run/udev/data";

struct GpuDevice {
    index: u16,
    label: String,
    busy: PathBuf,
    memory_used: PathBuf,
    memory_total: PathBuf,
    temperature: Option<PathBuf>,
    clock: Option<PathBuf>,
}

impl GpuDevice {
    fn sample(&self) -> GpuUsage {
        GpuUsage {
            label: self.label.clone(),
            utilization_percent: read_field(&self.busy, |value| value.parse::<u32>().ok())
                .filter(|percent| *percent <= 100)
                .map(|percent| percent as f32),
            memory_used: read_field(&self.memory_used, |value| value.parse().ok()),
            memory_total: read_field(&self.memory_total, |value| value.parse().ok())
                .filter(|total| *total > 0),
            temperature_celsius: self
                .temperature
                .as_ref()
                .and_then(|path| read_field(path, |value| value.parse::<i64>().ok()))
                .map(|millidegrees| millidegrees as f32 / 1_000.0)
                .filter(|degrees| (-50.0..=150.0).contains(degrees)),
            clock_mhz: self
                .clock
                .as_ref()
                .and_then(|path| read_field(path, |value| value.parse::<u64>().ok()))
                .and_then(|hertz| u32::try_from(hertz / 1_000_000).ok()),
        }
    }
}

fn read_field<T>(path: &Path, parse: impl FnOnce(&str) -> Option<T>) -> Option<T> {
    let mut buffer = [0; 64];
    let count = File::open(path).ok()?.read(&mut buffer).ok()?;
    parse(std::str::from_utf8(&buffer[..count]).ok()?.trim())
}

fn gpu_model(device: &Path, udev_root: &Path) -> Option<String> {
    let canonical = fs::canonicalize(device).ok()?;
    let slot = canonical.file_name()?.to_str()?;
    if slot.len() > 16
        || !slot.contains(':')
        || !slot
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() || matches!(byte, b':' | b'.'))
    {
        return None;
    }
    let mut data = String::new();
    File::open(udev_root.join(format!("+pci:{slot}")))
        .ok()?
        .take(4097)
        .read_to_string(&mut data)
        .ok()?;
    if data.len() > 4096 {
        return None;
    }
    data.lines()
        .find_map(|line| line.strip_prefix("E:ID_MODEL_FROM_DATABASE="))
        .map(str::trim)
        .filter(|model| !model.is_empty())
        .map(|model| sanitize_label(format!("AMD {model}"), MAX_HARDWARE_BYTES))
}

fn discover_gpus(root: &Path, udev_root: &Path) -> Option<Vec<GpuDevice>> {
    let mut devices = Vec::new();
    for entry in fs::read_dir(root).ok()?.take(MAX_DRM_ENTRIES).flatten() {
        let name = entry.file_name();
        let Some(index) = name
            .to_str()
            .and_then(|name| name.strip_prefix("card"))
            .and_then(|digits| digits.parse::<u16>().ok())
        else {
            continue;
        };
        let device = entry.path().join("device");
        if read_field(&device.join("vendor"), |vendor| Some(vendor == "0x1002")) != Some(true) {
            continue;
        }
        let hwmon = fs::read_dir(device.join("hwmon")).ok().and_then(|entries| {
            entries
                .take(16)
                .flatten()
                .filter(|entry| {
                    let name = entry.file_name();
                    name.to_str().is_some_and(|name| {
                        name.strip_prefix("hwmon")
                            .is_some_and(|digits| digits.parse::<u16>().is_ok())
                    })
                })
                .map(|entry| entry.path())
                .min()
        });
        devices.push(GpuDevice {
            index,
            label: gpu_model(&device, udev_root).unwrap_or_else(|| {
                read_field(&device.join("device"), |id| {
                    u16::from_str_radix(id.trim_start_matches("0x"), 16).ok()
                })
                .map_or_else(
                    || format!("AMD GPU (card{index}; model unavailable)"),
                    |id| format!("AMD PCI 1002:{id:04X} (card{index})"),
                )
            }),
            busy: device.join("gpu_busy_percent"),
            memory_used: device.join("mem_info_vram_used"),
            memory_total: device.join("mem_info_vram_total"),
            temperature: hwmon.as_ref().map(|path| path.join("temp1_input")),
            clock: hwmon.map(|path| path.join("freq1_input")),
        });
    }
    devices.sort_unstable_by_key(|device| device.index);
    devices.truncate(MAX_GPUS);
    Some(devices)
}

/// Keep counters across requests: sysinfo's CPU and process percentages need two refreshes.
pub(crate) struct Collector {
    host: String,
    cpu_model: Option<String>,
    system: System,
    disks: Disks,
    networks: Networks,
    gpu_devices: Option<Vec<GpuDevice>>,
    last_network_refresh: Option<Instant>,
}

impl Collector {
    pub(crate) fn new(host_name: Option<String>) -> Result<Self> {
        let host = host_name
            .or_else(System::host_name)
            .context("cannot determine host name")?;
        let host = sanitize_label(host, MAX_HOST_BYTES);
        let mut system = System::new();
        system.refresh_cpu_usage();
        let cpu_model = system
            .cpus()
            .first()
            .map(|cpu| sanitize_label(cpu.brand().trim().to_owned(), MAX_HARDWARE_BYTES))
            .filter(|model| !model.is_empty());
        system.refresh_processes_specifics(
            ProcessesToUpdate::All,
            true,
            ProcessRefreshKind::nothing()
                .with_cpu()
                .with_memory()
                .without_tasks(),
        );
        Ok(Self {
            host,
            cpu_model,
            system,
            disks: Disks::new_with_refreshed_list(),
            networks: Networks::new_with_refreshed_list(),
            gpu_devices: discover_gpus(Path::new(DRM_ROOT), Path::new(UDEV_DATA_ROOT)),
            last_network_refresh: None,
        })
    }

    pub(crate) fn sample(&mut self) -> Snapshot {
        self.system.refresh_cpu_usage();
        self.system.refresh_memory();
        self.system.refresh_processes_specifics(
            ProcessesToUpdate::All,
            true,
            ProcessRefreshKind::nothing()
                .with_cpu()
                .with_memory()
                .without_tasks(),
        );
        self.disks.refresh(true);
        self.networks.refresh(true);
        let now = Instant::now();
        let interval = self
            .last_network_refresh
            .replace(now)
            .map(|then| now.duration_since(then));
        let rx = self
            .networks
            .iter()
            .fold(0u64, |sum, (_, net)| sum.saturating_add(net.received()));
        let tx = self
            .networks
            .iter()
            .fold(0u64, |sum, (_, net)| sum.saturating_add(net.transmitted()));
        let (rx_bytes_per_second, tx_bytes_per_second) = match interval {
            Some(elapsed) => (
                bytes_per_second(rx, elapsed.as_secs_f64()),
                bytes_per_second(tx, elapsed.as_secs_f64()),
            ),
            None => (0, 0),
        };

        let mut disks: Vec<DiskUsage> = self
            .disks
            .iter()
            .filter(|disk| disk.total_space() > 0)
            .map(|disk| DiskUsage {
                mount: sanitize_label(
                    disk.mount_point().to_string_lossy().into_owned(),
                    MAX_MOUNT_BYTES,
                ),
                used: disk.total_space().saturating_sub(disk.available_space()),
                total: disk.total_space(),
            })
            .collect();
        disks.sort_unstable_by(|a, b| a.mount.cmp(&b.mount));
        disks.truncate(MAX_DISKS);

        // Keep just the best references: no per-process names or full process list allocated.
        let mut top = Vec::with_capacity(MAX_PROCESSES);
        for process in self.system.processes().values() {
            let score = (
                finite_percent(process.cpu_usage()),
                process.memory(),
                process.pid().as_u32(),
            );
            let position = top.partition_point(|candidate: &&sysinfo::Process| {
                let other = (
                    finite_percent(candidate.cpu_usage()),
                    candidate.memory(),
                    candidate.pid().as_u32(),
                );
                process_before(other, score)
            });
            if position < MAX_PROCESSES {
                top.insert(position, process);
                if top.len() > MAX_PROCESSES {
                    top.pop();
                }
            }
        }
        let processes = top
            .into_iter()
            .map(|process| ProcessUsage {
                pid: process.pid().as_u32(),
                name: sanitize_label(
                    process.name().to_string_lossy().into_owned(),
                    MAX_PROCESS_NAME_BYTES,
                ),
                cpu_percent: finite_percent(process.cpu_usage()),
                memory_bytes: process.memory(),
            })
            .collect();

        let load = System::load_average();
        Snapshot {
            host: self.host.clone(),
            cpu_model: self.cpu_model.clone(),
            uptime_seconds: System::uptime(),
            cpu_percent: finite_percent(self.system.global_cpu_usage()),
            cores_percent: self
                .system
                .cpus()
                .iter()
                .take(MAX_CORES)
                .map(|cpu| finite_percent(cpu.cpu_usage()))
                .collect(),
            load_average: [load.one, load.five, load.fifteen],
            memory_used: self.system.used_memory(),
            memory_total: self.system.total_memory(),
            swap_used: self.system.used_swap(),
            swap_total: self.system.total_swap(),
            rx_bytes_per_second,
            tx_bytes_per_second,
            disks,
            gpus: self
                .gpu_devices
                .as_ref()
                .map(|devices| devices.iter().map(GpuDevice::sample).collect()),
            processes,
        }
    }
}

fn process_before(a: (f32, u64, u32), b: (f32, u64, u32)) -> bool {
    a.0 > b.0 || (a.0 == b.0 && (a.1 > b.1 || (a.1 == b.1 && a.2 < b.2)))
}

fn finite_percent(percent: f32) -> f32 {
    if percent.is_finite() {
        percent.max(0.0)
    } else {
        0.0
    }
}

fn sanitize_label(mut value: String, max_bytes: usize) -> String {
    let mut end = value.len().min(max_bytes);
    while !value.is_char_boundary(end) {
        end -= 1;
    }
    value.truncate(end);
    value.retain(|character| !character.is_control());
    value
}

fn bytes_per_second(bytes: u64, seconds: f64) -> u64 {
    if seconds > 0.0 {
        (bytes as f64 / seconds) as u64
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn displayed_labels_are_bounded_and_cannot_emit_control_sequences() {
        assert_eq!(sanitize_label("aé🦀b".into(), 4), "aé");
        assert_eq!(sanitize_label("é".into(), 1), "");
        assert_eq!(sanitize_label("a\x1b[31m\nb".into(), 32), "a[31mb");
    }

    #[test]
    fn process_ranking_breaks_ties_by_memory_then_pid() {
        assert!(process_before((4.0, 8, 10), (4.0, 7, 1)));
        assert!(process_before((4.0, 8, 1), (4.0, 8, 2)));
        assert!(!process_before((3.0, 200, 1), (4.0, 1, 2)));
    }

    #[test]
    fn network_rate_needs_positive_interval() {
        assert_eq!(bytes_per_second(20, 2.0), 10);
        assert_eq!(bytes_per_second(20, 0.0), 0);
    }

    #[test]
    fn sampler_caps_each_wire_collection() {
        let mut sampler = Collector::new(Some("é".repeat(130))).unwrap();
        let first = sampler.sample();
        let second = sampler.sample();
        assert!(first.host.len() <= MAX_HOST_BYTES);
        assert!(
            first
                .cpu_model
                .as_ref()
                .is_none_or(|model| model.len() <= MAX_HARDWARE_BYTES)
        );
        assert_eq!(first.rx_bytes_per_second, 0);
        assert_eq!(first.tx_bytes_per_second, 0);
        for snapshot in [&first, &second] {
            assert!(snapshot.cores_percent.len() <= MAX_CORES);
            assert!(snapshot.disks.len() <= MAX_DISKS);
            assert!(snapshot.processes.len() <= MAX_PROCESSES);
            assert!(
                snapshot
                    .gpus
                    .as_ref()
                    .is_none_or(|gpus| gpus.len() <= MAX_GPUS)
            );
            assert!(
                snapshot
                    .disks
                    .iter()
                    .all(|disk| disk.mount.len() <= MAX_MOUNT_BYTES)
            );
            assert!(
                snapshot
                    .processes
                    .iter()
                    .all(|proc| proc.name.len() <= MAX_PROCESS_NAME_BYTES)
            );
            assert!(
                snapshot
                    .disks
                    .windows(2)
                    .all(|pair| pair[0].mount <= pair[1].mount)
            );
            assert!(snapshot.processes.windows(2).all(|pair| process_before(
                (pair[0].cpu_percent, pair[0].memory_bytes, pair[0].pid),
                (pair[1].cpu_percent, pair[1].memory_bytes, pair[1].pid),
            )));
        }
    }
    #[test]
    fn amdgpu_sysfs_sample_distinguishes_missing_from_zero_and_ignores_other_devices() {
        let root = tempfile::tempdir().unwrap();
        let drm = root.path();
        let amd = drm.join("card7/device");
        let sensors = amd.join("hwmon/hwmon3");
        fs::create_dir_all(&sensors).unwrap();
        fs::write(amd.join("vendor"), "0x1002\n").unwrap();
        fs::write(amd.join("device"), "0x1586\n").unwrap();
        fs::write(amd.join("gpu_busy_percent"), "42\n").unwrap();
        fs::write(amd.join("mem_info_vram_used"), "536870912\n").unwrap();
        fs::write(amd.join("mem_info_vram_total"), "2147483648\n").unwrap();
        fs::write(sensors.join("temp1_input"), "68000\n").unwrap();
        fs::write(sensors.join("freq1_input"), "2200000000\n").unwrap();

        let other = drm.join("card2/device");
        fs::create_dir_all(&other).unwrap();
        fs::write(other.join("vendor"), "0x8086\n").unwrap();
        let connector = drm.join("card1-HDMI-A-1/device");
        fs::create_dir_all(&connector).unwrap();
        fs::write(connector.join("vendor"), "0x1002\n").unwrap();

        let devices = discover_gpus(drm, &drm.join("udev")).unwrap();
        assert_eq!(devices.len(), 1);
        let gpu = devices[0].sample();
        assert_eq!(gpu.label, "AMD PCI 1002:1586 (card7)");
        assert_eq!(gpu.utilization_percent, Some(42.0));
        assert_eq!(gpu.memory_used, Some(536_870_912));
        assert_eq!(gpu.memory_total, Some(2_147_483_648));
        assert_eq!(gpu.temperature_celsius, Some(68.0));
        assert_eq!(gpu.clock_mhz, Some(2200));

        fs::write(amd.join("gpu_busy_percent"), "0\n").unwrap();
        assert_eq!(devices[0].sample().utilization_percent, Some(0.0));
        fs::write(amd.join("gpu_busy_percent"), "not a number\n").unwrap();
        fs::write(amd.join("mem_info_vram_total"), "0\n").unwrap();
        fs::remove_file(sensors.join("temp1_input")).unwrap();
        let missing = devices[0].sample();
        assert_eq!(missing.utilization_percent, None);
        assert_eq!(missing.memory_total, None);
        assert_eq!(missing.temperature_celsius, None);
        assert!(discover_gpus(&drm.join("missing"), &drm.join("udev")).is_none());
        assert!(
            discover_gpus(drm.join("card2").as_path(), &drm.join("udev"))
                .unwrap()
                .is_empty()
        );
    }

    #[cfg(unix)]
    #[test]
    fn gpu_model_uses_udev_pci_name_and_falls_back_when_missing_or_oversized() {
        let root = tempfile::tempdir().unwrap();
        let drm = root.path().join("drm");
        let card = drm.join("card3");
        let pci = root.path().join("0000:c5:00.0");
        let udev = root.path().join("udev");
        fs::create_dir_all(&card).unwrap();
        fs::create_dir_all(&pci).unwrap();
        fs::create_dir_all(&udev).unwrap();
        std::os::unix::fs::symlink(&pci, card.join("device")).unwrap();
        fs::write(pci.join("vendor"), "0x1002\n").unwrap();
        fs::write(pci.join("device"), "0x150e\n").unwrap();
        let entry = udev.join("+pci:0000:c5:00.0");
        fs::write(
            &entry,
            "E:ID_MODEL_FROM_DATABASE=Strix [Radeon 880M / 890M]\n",
        )
        .unwrap();
        let named = discover_gpus(&drm, &udev).unwrap();
        assert_eq!(named[0].label, "AMD Strix [Radeon 880M / 890M]");

        fs::write(&entry, "E:ID_MODEL_FROM_DATABASE=\n").unwrap();
        assert_eq!(
            discover_gpus(&drm, &udev).unwrap()[0].label,
            "AMD PCI 1002:150E (card3)"
        );
        fs::write(&entry, "x".repeat(4097)).unwrap();
        assert_eq!(
            discover_gpus(&drm, &udev).unwrap()[0].label,
            "AMD PCI 1002:150E (card3)"
        );
    }

    #[test]
    fn gpu_admission_is_sorted_and_capped() {
        let root = tempfile::tempdir().unwrap();
        for index in (0..MAX_GPUS + 2).rev() {
            let device = root.path().join(format!("card{index}/device"));
            fs::create_dir_all(&device).unwrap();
            fs::write(device.join("vendor"), "0x1002\n").unwrap();
        }
        let devices = discover_gpus(root.path(), &root.path().join("udev")).unwrap();
        assert_eq!(devices.len(), MAX_GPUS);
        assert_eq!(devices[0].label, "AMD GPU (card0; model unavailable)");
        assert_eq!(
            devices[MAX_GPUS - 1].label,
            "AMD GPU (card7; model unavailable)"
        );
        assert_eq!(devices[0].sample().utilization_percent, None);
    }
}
