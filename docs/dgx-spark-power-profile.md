# DGX Spark GPU power profile

## Purpose

This note describes the DGX Spark GPU max-clock cap. The cap is the
repository's serving power profile for the DeepSeek V4 Flash 0731 nvfp4
cluster.

The cap exists because decode is memory-bound. Capping the GPU clock does not
reduce decode output. The cap reduces prefill speed and other compute-bound
work. The cap reduces GPU power and temperature.

The lock does not survive a reboot. The configuration applies the lock at
boot through a systemd unit. A reboot without that unit returns every GPU to
boost clocks.

## Measured data

The data below is per GPU from `nvtop`. Real wall power is higher than the
driver-reported power. Measure the real delta at the PDU.

| Max clock (MHz) | GPU power (W) | GPU temp (C) |
|---|---|---|
| 2455 (boost) | ~47 | ~72 |
| 2300 | ~34 | ~67 |
| 2200 | ~32 | ~66 |
| 2000 | ~27 | ~63 |
| 1800 | ~23 | ~61 |

## Policy

- The cap is 2200 MHz with a floor of 0 MHz.
- The cap applies to every GPU on every Spark, at boot.
- 2200 MHz is the chosen point. It saves about 15 W per GPU over boost.
- Lower settings save only 4-5 W per step while compute cost grows.
- Decode-heavy serving keeps full output under the cap.
- Prefill-heavy batch runs use boost clocks. Release the cap before those
  runs.

## How the cap applies

The `dgx-spark` machine tag enables `services.dgx-spark-power`. The module
renders one systemd unit, `dgx-spark-power.service`.

The unit runs as a oneshot service after `nvidia-persistenced.service`. It
applies `nvidia-smi -lgc 0,2200` to each GPU. It releases the cap with
`nvidia-smi -rgc` when it stops.

The unit:

- Applies the cap at boot.
- Keeps the cap while the machine serves.
- Releases the cap when the unit stops.

## Manual control

Apply the cap by hand:

```sh
sudo nvidia-smi -lgc 0,2200
```

Release the cap:

```sh
sudo nvidia-smi -rgc
```

Or release it through the unit:

```sh
systemctl stop dgx-spark-power
```

Restart the unit after a stop to re-apply the cap:

```sh
systemctl start dgx-spark-power
```

## Verify

Make sure that the cap is live:

```sh
nvidia-smi -q -d CLOCK
```

Read the `Max` clock value. It must show 2200 MHz. If it shows 2455 MHz, the
unit is not applied. Check the unit status first:

```sh
systemctl status dgx-spark-power
```

## Reboot boundary

The NVIDIA clock lock is volatile. It does not survive a boot. Only the
systemd unit re-applies it. Do not rely on a hand-applied lock across a
reboot.

## Costs

The cap slows prefill and any other compute-bound work. It does not slow
decode. Wall power is higher than `nvtop` shows. Measure the real saving at
the PDU before you promise a specific number.

## Source

The applied measurement set comes from the operator's DGX Spark cluster
running DeepSeek V4 Flash 0731 nvfp4 with the MiaAI lab recipe.
